import Foundation
import Vapor

/// Future usada em Vapor e NIO.
typealias Future<T> = EventLoopFuture<T>

// configures your application
public func configure(_ app: Application) throws {
    // config do servidor
    app.http.server.configuration.serverName = "Planejador de Disciplinas"
    if case .production = app.environment {
        app.http.server.configuration.responseCompression = .enabled
    }
    // config do client
    app.http.client.configuration.httpVersion = .http1Only
    app.http.client.configuration.connectionPool.concurrentHTTP1ConnectionsPerHostSoftLimit = 24
    app.http.server.configuration.hostname = "0.0.0.0"

    // serve arquivo da pasta /Public
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // formata melhor o JSON no modo de desenvolvimento
    if case .development = app.environment {
        Match.encodeScoresForSending()
        enablePrettyPrintForJSON()
    }

    initializeControllers(app)

    // register routes
    try routes(app)
}

/// Formata output de JSON com chaves ordenadas e identadas.
private func enablePrettyPrintForJSON() {
    let globalEncoder = try? ContentConfiguration.global.requireEncoder(for: .json)
    let encoder = globalEncoder as? JSONEncoder ?? JSONEncoder()

    encoder.outputFormatting.formUnion([.sortedKeys, .prettyPrinted])
    ContentConfiguration.global.use(encoder: encoder, for: .json)
}

private func initializeControllers(_ app: Application) {
    // Inicia thread para preparar os dados.
    // Pega instância de singleton pela primeira vez para
    // carregar os dados de forma assíncrona.
    // `.shared` é lazy por ser estático, e por isso
    // roda de forma assíncrona abaixo.
    _ = app.eventLoopGroup.performWithTask {
        try await app.disciplines
    }
    _ = app.eventLoopGroup.performWithTask {
        try await app.courses
    }
}
