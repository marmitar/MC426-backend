import Foundation
import Services
import Vapor

extension Discipline {
    /// Controlador de disciplinas recuperadas por Scraping.
    struct Controller {
        private let db: Database<Discipline>

        init(logger: Logger? = nil) throws {
            let data = try Discipline.scrape(logger: logger)
            self.db = try Database(entries: data.flatMap { $1 }, logger: logger)
        }

        /// Recupera disciplina por código.
        func get(code: String) -> Discipline? {
            self.db.find(.code, equals: code)
        }
    }
}
