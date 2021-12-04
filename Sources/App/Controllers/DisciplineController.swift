import Foundation
import Vapor

extension Discipline {
    /// Controlador das disciplinas recuperadas por Scraping.
    ///
    /// Classe singleton. Usar `app.disciplines` para pegar instância.
    final class Controller: ContentController<Discipline> {
        /// Inicializador privado do singleton.
        init(app: Application) async throws {
            let data = try await app.webScraper.scrape(Discipline.self)
            try super.init(entries: data, logger: app.logger)
        }

        /// Busca apenas entre as disciplinas
        func fetchDiscipline(_ req: Request) throws -> Discipline {
            try fetchContent(on: .code, req)
        }
    }
}

extension Application {
    /// Chave para acesso do singleton
    private enum DisciplineControllerKey: StorageKey, LockKey {
        typealias Value = EventLoopFuture<Discipline.Controller>
    }

    /// O `Future` do controlador, que fica armazenado em `storage`.
    ///
    /// Só deve existir um desses future e os acessos esperam nele.
    private var disciplinesFuture: EventLoopFuture<Discipline.Controller> {
        if let future = self.storage[DisciplineControllerKey.self] {
            return future
        } else {
            let future = self.eventLoopGroup.performWithTask {
                try await Discipline.Controller(app: self)
            }
            self.storage[DisciplineControllerKey.self] = future
            return future
        }
    }

    /// Instância compartilhada do singleton.
    var disciplines: Discipline.Controller {
        get async throws {
            try await self.locks
                .lock(for: DisciplineControllerKey.self)
                .withLock { self.disciplinesFuture }
                .get()
        }
    }
}

extension Request {
    /// Instância compartilhada do singleton.
    var disciplines: Discipline.Controller {
        get async throws {
            try await self.application.disciplines
        }
    }
}
