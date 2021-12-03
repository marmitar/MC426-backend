import Foundation
import Vapor

extension Course {
    /// Controlador dos cursos recuperados por Scraping.
    ///
    /// Classe singleton. Usar `.shared` para pegar instância.
    final class Controller: ContentController<Course> {

        /// Instância compartilhada do singleton.
        ///
        /// Por ser estática, é lazy por padrão, ou seja,
        /// o database será criado apenas na primeira chamada.
        static let shared: Controller = {
            do {
                return try Controller()
            } catch {
                fatalError(error.localizedDescription)
            }
        }()

        /// Inicializador privado do singleton.
        private init() throws {
            let data = try Course.scrape(logger: .controllerLogger)
            try super.init(entries: Array(data.values), logger: .controllerLogger)
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
