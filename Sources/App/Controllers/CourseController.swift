import Foundation
import Services
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
        static let shared = try! Controller(logger: .controllerLogger)

        /// Inicializador privado do singleton.
        private init(logger: Logger) throws {
            let data = try Course.scrape(logger: .controllerLogger)
            try super.init(entries: Array(data.values), logger: .controllerLogger)
        }

        /// Recupera curso por código.
        private func findCourseWith(code: String) -> Course? {
            self.db.find(.code, equals: code)
        }
        
        func fetchCourse(_ req: Request) throws -> Course {
            // SAFETY: o router do Vapor só deixa chegar aqui com o parâmetro
            let code = req.parameters.get("code")!
            
            if let course = self.findCourseWith(code: code) {
                return course
                
            } else {
                throw Abort(.notFound)
            }
        }
        
        func fetchCourseTree(_ req: Request) throws -> CourseTree {
            // SAFETY: o router do Vapor só deixa chegar aqui com o parâmetro
            let code = req.parameters.get("code")!
            let variant = req.parameters.get("variant")!
            
            guard
                let index = Int(variant),
                let course = self.findCourseWith(code: code),
                let tree = course.getTree(forIndex: index)
            else {
                throw Abort(.notFound)
            }
            
            return tree
        }
    }
}
