import Foundation
import Vapor
import Services

// configures your application
public func configure(_ app: Application) throws {
    app.http.server.configuration.serverName = "Planejador de Disciplinas"
    // serve files from /Public folder
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // recupera dados por scraping
    app.storage[ScrapedData.self] = try .init(app)

    // register routes
    try routes(app)
}

/// Controlador de dados recuperados por Web Scraping.
final class ScrapedData: StorageKey {
    typealias Value = ScrapedData
    /// Logger da aplicação, para reutilizar depois.
    private let logger: Logger
    /// Controlador de disciplinas.
    private let disciplines: Discipline.Controller

    fileprivate init(_ app: Application) throws {
        self.logger = app.logger
        self.disciplines = try .init(logger: self.logger)
    }

    /// Recupera uma disciplina pelo seu código.
    func getDiscipline(with code: String) -> Discipline? {
        self.disciplines.get(code: code)
    }

    /// Busca dentre os dados carregados na memória.
    func search(for text: String, limitingTo limit: Int? = nil) -> [Discipline]  {
        let (elapsed, matches) = withTiming {
            self.disciplines.search(for: text, limit: limit)
        }
        self.logger.info("Searched for \"\(text)\" with \(matches.count) results in \(elapsed) secs.")

        // TODO: outros tipos de dados
        return matches.map { $0.item }
    }
}

extension Request {
    /// Dados recuperados por scraping.
    var scrapedData: ScrapedData {
        // SAFETY: sempre vai estar inicializado em Request
        self.application.storage[ScrapedData.self]!
    }
}
