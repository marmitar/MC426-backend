//
//  File.swift
//
//
//  Created by Vitor Jundi Moriya on 04/11/21.
//

import Foundation
import Vapor

/// Controlador de um cconjunto de dados ``WebScrapable`` e ``Searchable``
protocol ContentController: Sendable {
    /// Tipo do dado que é controlado.
    associatedtype ControlledContent: Searchable & WebScrapable
        where ControlledContent.WebScrapingOutput: Sequence,
            ControlledContent.WebScrapingOutput.Element == ControlledContent

    /// Inicializa controlador com dados já recuperados do scraping.
    init(content: [ControlledContent])
}

extension ContentController {
    /// Cria novo controlador na aplicação fazendo o scraping dos dados.
    @inlinable
    init(app: Application) async throws {
        let output = try await app.webScraper.scrape(ControlledContent.self)
        let content = Array(output)

        self.init(content: content)
    }
}

extension Application {
    /// Chave para acesso do ``Controller`` no ``Application.storage``.
    private enum ControllerKey<Controller>: StorageKey {
        typealias Value = Task<Controller?, Never>
    }

    /// Inicializa controlador em uma nova ``Task`` e salva a handle no ``storage``.
    ///
    /// - parameter type: Tipo do controlador que será inicializado.
    /// - returns: Handle da ``Task``, que resolve para `nil` em caso de erros, imprimindo o erro no logger.
    /// - important: Não deve ser usado após ``Application.run``.
    @discardableResult
    func initialize<Controller: ContentController>(controller type: Controller.Type) -> Task<Controller?, Never> {

        let task = Task { () -> Controller? in
            do {
                return try await Controller(app: self)
            } catch {
                self.logger.report(
                    level: .error,
                    error,
                    Service: Controller.self,
                    additional: "Could not initialize controller."
                )
                return nil
            }
        }

        self.storage[ControllerKey<Controller>.self] = task
        return task
    }

    /// Acesso da instância compartilhada do ``Controller``, esperando sua inicialização ser concluída.
    ///
    /// - parameter type: Tipo do controlador a ser acessado ou instanciado.
    /// - returns: Controlador já inicializado.
    /// - throws: `503 Service Unavailable` se houve erro na inicialização do controlador.
    func instance<Controller: ContentController>(controller type: Controller.Type) async throws -> Controller {
        let task = self.storage[ControllerKey<Controller>.self]

        if let controller = await task?.value {
            return controller
        } else {
            throw Abort(.serviceUnavailable)
        }
    }
}
