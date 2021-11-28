import Foundation
import Vapor
import SwiftSoup

/// Algum dado que é recuperado da internet, em geral através de parsing HTML.
protocol WebScrapabl: Codable { // TODO: fix nome
    /// Nome do arquivo usado para fazer caching dos resultados.
    ///
    /// Padrão: nome do tipo.
    static var cacheFile: String {
        @inlinable get
    }

    /// Faz o scraping do tipo de forma assíncrona usando o `WebScraper` da aplicação.
    @inlinable
    static func scrape(with scraper: WebScraper) async throws -> Self
}

extension WebScrapabl {
    @inlinable
    static var cacheFile: String {
        "\(Self.self)"
    }
}

extension Application {
    private enum WebScraperKey: StorageKey {
        typealias Value = WebScraper
    }

    /// WebScraper padrão da aplicação.
    var webScraper: WebScraper {
        // faz a inicialização de modo lazy
        if let scraper = self.storage[WebScraperKey.self] {
            return scraper
        } else {
            let scraper = WebScraper(app: self)
            self.storage[WebScraperKey.self] = scraper
            return scraper
        }
    }
}

/// Versão HTTP usada nas requisições com o `client`.
typealias HTTPVersion = HTTPClient.Configuration.HTTPVersion

/// Serviço resposável por fazer o scraping dos dados, fazendo as requisições necessárias e o caching dos resultados.
struct WebScraper {
    // MARK: - Configuração

    struct Configuration {
        /// Avisa se a aplicação está usando versões mais novas do HTTP.
        ///
        /// Vários sites mais antigos tem problema em tratar corretamente requisições em HTTP/2.
        public var warnAboutHttpVersion: Bool = true
        /// Nome do diretório usado para caching em `Resources`. (padrão: "Cache")
        public var cacheDirectory: String = "Cache"
        /// Se o `WebScraper` deve fazer e usar caching dos resultados de scraping.
        public var useCaching: Bool = true
    }

    /// Configuração do `WebScraper`.
    static var configuration = Configuration()

    /// A aplicação que está usando o `WebScraper`.
    private let app: Application
    /// Versão HTTP usada pelo `client` da aplicação.
    var httpVersion: HTTPVersion {
        self.app.http.client.configuration.httpVersion
    }
    /// Logger da aplciação, exportado para uso durante o scraping.
    var logger: Logger {
        self.app.logger
    }

    /// Incializa `WebScraper` para a aplicação.
    init(app: Application) {
        self.app = app

        if Self.configuration.warnAboutHttpVersion
            && "\(self.httpVersion)" != "\(HTTPVersion.http1Only)" {

            self.logger.warning(
                """
                HTTPClient may be using another HTTP version for requests. This could result in remoteConnectionClosed
                for site applications. More details on https://github.com/swift-server/async-http-client/issues/488.
                """,
                metadata: [
                    "Service": "\(Self.self)",
                    "HTTP Version Configuration": "\(self.httpVersion)"
                ]
            )
        }
    }
}

extension WebScraper {
    // MARK: - Requisições HTTP

    /// Faz a requisição e decodificação de um conteúdo da internet.
    @inlinable
    func get<Content: Decodable>(
        _ type: Content.Type = Content.self,
        from url: String,
        using decoder: ContentDecoder? = nil
    ) async throws -> Content {
        let response = try await self.app.client.get(URI(string: url))
        if let decoder = decoder {
            return try response.content.decode(type, using: decoder)
        } else {
            return try response.content.decode(type)
        }
    }

    /// Faz a requisição e o parsing de uma página HTML.
    @inlinable
    func getHTML(from url: String) async throws -> Document {
        let text: String = try await self.get(from: url, using: PlaintextDecoder())
        let document = try SwiftSoup.parse(text, url)
        return document
    }
}

extension WebScraper {
    // MARK: - Scraping e caching

    /// Faz o scraping do conteúdo, se necessário. Sempre prefere usar o caching para carregar os dados.
    @inlinable
    func scrape<Content: WebScrapabl>(_ type: Content.Type = Content.self) async throws -> Content {
        if Self.configuration.useCaching {
            if let content = await self.tryLoadJSON(type, from: self.cacheFile(for: type)) {
                return content
            }
            // em caso de erro, ignora o cache
        }
        return try await self.scrapeFresh(type)
    }

    /// Faz o scraping de um conteúdo novo e sobrescreve o arquivo de caching.
    @inlinable
    func scrapeFresh<Content: WebScrapabl>(_ type: Content.Type = Content.self) async throws -> Content {
        let content = try await Content.scrape(with: self)

        if Self.configuration.useCaching {
            // faz o salvamento do cache em outra task, sem travar essa
            Task { await self.trySaveJSON(content, at: self.cacheFile(for: type)) }
        }
        return content
    }

    /// Tenta executar `loadJSON` ou acusa um erro pelo `logger`.
    ///
    /// Usa o FileManager por ser mais simples, já que essa função roda no background.
    private func tryLoadJSON<Content: Decodable>(
        _ type: Content.Type = Content.self,
        from path: String
    ) async -> Content? {
        do {
            return try await self.loadJSON(type, from: path)
        } catch {
            self.logger.report(
                level: .info,
                error,
                Service: Self.self,
                additional: "Could not load scraped content from JSON file",
                metadata: ["Content": "\(Content.self)", "File Location": path]
            )
            return nil
        }
    }

    /// Tenta executar `saveJSON` ou acusa um erro pelo `logger`.
    ///
    /// Usa o FileManager por ser mais simples, já que essa função roda no background.
    private func trySaveJSON<Content: Codable>(_ content: Content, at path: String) async {
        do {
            try await self.saveJSON(content, at: path)
        } catch {
            self.logger.report(
                level: .error,
                error,
                Service: Self.self,
                additional: "Could not save scraped content to JSON file",
                metadata: ["Content": "\(Content.self)", "File Location": path]
            )
        }
    }

    /// Faz a leitura do arquivo em `path` e converte para `Content` usando um decoder de JSON.
    ///
    /// Usa o NonBlockingFileIO do swift-nio, por ser async e bem eficiente.
    private func loadJSON<Content: Decodable>(
        _ type: Content.Type = Content.self,
        from path: String
    ) async throws -> Content {
        let eventLoop = self.app.eventLoopGroup.next()
        let file = try await self.app.fileio.openFile(path: path, mode: .read, eventLoop: eventLoop).get()
        let byteCount = try await self.app.fileio.readFileSize(fileHandle: file, eventLoop: eventLoop).get()

        var content = try await self.app.fileio.read(
            fileHandle: file,
            byteCount: Int(byteCount),
            allocator: ByteBufferAllocator(),
            eventLoop: eventLoop
        ).get()

        let data = content.readData(length: content.readableBytes)
        return try JSONDecoder().decode(type, from: data ?? Data())
    }

    /// Salva `content` como um arquivo JSON em `path`.
    private func saveJSON<Content: Codable>(_ content: Content, at path: String) async throws {
        let data = try JSONEncoder().encode(content)

        try self.ensureDirectoryExists(at: self.cacheDirectory)
        self.removeFileIfExists(at: path)

        try self.createFileWith(contents: data, at: path)
    }
}

extension WebScraper {
    // MARK: - Arquivos e diretórios

    /// Diretório usado para caching dos resultados de parsing.
    var cacheDirectory: URL {
        var resources = URL(fileURLWithPath: self.app.directory.resourcesDirectory, isDirectory: true)
        // remove partes como "/" e "." do nome da pasta antes de inserir na URL
        resources.appendPathComponent(Self.configuration.cacheDirectory.replacingNonAlphaNum(), isDirectory: true)
        resources.standardize()
        return resources
    }

    /// Path do arquivo usado para caching de `Content`.
    @inlinable
    func cacheFile<Content: WebScrapabl>(for content: Content.Type) -> String {
        // remove partes como "/" e "." do nome do arquivo para sempre funcionar corretamente
        let filename = "\(Content.cacheFile.replacingNonAlphaNum()).json"
        return self.cacheDirectory.appendingPathComponent(filename, isDirectory: false).path
    }

    /// Tenta remover toda a pasta de cache, ignorando erros.
    private func clearCacheDirectory() {
        try? FileManager.default.removeItem(at: self.cacheDirectory)
    }

    /// Tenta remover arquivo em `path`, ignorando erros.
    private func removeFileIfExists(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Checa que `path` existe e é uma pasta ou cria uma nova.
    private func ensureDirectoryExists(at path: URL) throws {
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: path.path, isDirectory: &isDirectory)

        if !(exists && isDirectory.boolValue) {
            try? FileManager.default.removeItem(at: path)

            try FileManager.default.createDirectory(
                at: self.cacheDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    /// Cria arquivo em `path` com um conteúdo predefinido.
    private func createFileWith(contents: Data, at path: String) throws {
        let successful = FileManager.default.createFile(
            atPath: path,
            contents: contents
        )

        if !successful {
            throw FileCreationError(at: path, with: contents)
        }
    }

    /// Erro durante a criação do arquivo.
    private struct FileCreationError: DebuggableError {
        let path: String
        let contents: Data?
        let attributes: [FileAttributeKey: Any]

        var contentSize: Int {
            self.contents?.count ?? 0
        }

        init(
            at path: String,
            with contents: Data? = nil,
            with attributes: [FileAttributeKey: Any] = [:],
            file: String = #file,
            function: String = #function,
            line: UInt = #line,
            column: UInt = #column,
            stackTrace: StackTrace? = .capture()
        ) {
            self.path = path
            self.contents = contents
            self.attributes = attributes

            self.source = .init(
                file: file,
                function: function,
                line: line,
                column: column
            )
            self.stackTrace = stackTrace
        }

        // MARK: - DebuggableError

        let stackTrace: StackTrace?

        let source: ErrorSource?

        var logLevel: Logger.Level {
            .error
        }

        var identifier: String {
            "FileCreationError"
        }

        var reason: String {
            "Could not a create file (\(self.contentSize)b) at \(self.path) (unknown reason)."
        }
    }
}
