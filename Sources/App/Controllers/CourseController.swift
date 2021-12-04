import Foundation
import Vapor

extension Course {
    /// Controlador dos cursos recuperados por Scraping.
    ///
    /// Classe singleton. Usar `app.courses` para pegar instância.
    final class Controller: ContentController<Course> {
        /// Inicializador privado do singleton.
        init(app: Application) async throws {
            let data = try await app.webScraper.scrape(Course.self)
            try super.init(entries: data, logger: app.logger)
        }

        /// Recupera curso por código.
        func fetchCourse(_ req: Request) throws -> Course {
            try fetchContent(on: .code, req)
        }

        func fetchCourseTree(_ req: Request) throws -> Course.Tree {
            // SAFETY: o router do Vapor só deixa chegar aqui com o parâmetro
            let variant = req.parameters.get("variant")!

            let course = try self.fetchCourse(req)

            guard
                let index = Int(variant),
                let tree = course.trees.get(at: index)
            else {
                throw Abort(.notFound)
            }

            return tree
        }
    }
}

extension Application {
    /// Chave para acesso do singleton
    private enum CourseControllerKey: StorageKey, LockKey {
        typealias Value = EventLoopFuture<Course.Controller>
    }

    /// O `Future` do controlador, que fica armazenado em `storage`.
    ///
    /// Só deve existir um desses future e os acessos esperam nele.
    private var coursesFuture: EventLoopFuture<Course.Controller> {
        if let future = self.storage[CourseControllerKey.self] {
            return future
        } else {
            let future = self.eventLoopGroup.performWithTask {
                try await Course.Controller(app: self)
            }
            self.storage[CourseControllerKey.self] = future
            return future
        }
    }

    /// Instância compartilhada do singleton.
    var courses: Course.Controller {
        get async throws {
            try await self.locks
                .lock(for: CourseControllerKey.self)
                .withLock { self.coursesFuture }
                .get()
        }
    }
}

extension Request {
    /// Instância compartilhada do singleton.
    var courses: Course.Controller {
        get async throws {
            try await self.application.courses
        }
    }
}
