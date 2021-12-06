import Foundation
import Vapor

/// Representação de uma matéria.
struct Discipline: Content, Hashable, Sendable {
    /// Código da disciplina.
    let code: String
    /// Nome da disciplina.
    let name: String
    /// Número de créditos.
    let credits: UInt
    /// Grupos de requisitos da disciplina.
    let reqs: ArraySet<ArraySet<Requirement>>
    /// Disciplina que tem essa como requisito.
    let reqBy: ArraySet<String>
    /// Ementa da disciplina.
    let syllabus: String

    /// Requisito de uma disciplina.
    struct Requirement: Content, Hashable, Comparable {
        /// Código de requisito.
        let code: String
        /// Se o requisito é parcial.
        let partial: Bool
        /// Se o requisito não é uma disciplina propriamente.
        let special: Bool

        static func < (_ first: Self, _ second: Self) -> Bool {
            first.code < second.code
        }
    }
}

extension Discipline: Searchable {

    /// Propriedades buscáveis na disciplina.
    enum Properties: SearchableProperty {
        /// Busca por código da disciplina.
        case code
        /// Busca pelo nome da disciplina.
        case name
        /// Busca pela ementa da disciplina.
        case syllabus

        @inlinable
        func get(from item: Discipline) -> String {
            switch self {
                case .code:
                    return item.code
                case .name:
                    return item.name
                case .syllabus:
                    return item.syllabus
            }
        }

        @inlinable
        var weight: Double {
            switch self {
                // maior peso para o código, que é mais exato
                case .code:
                    return 0.6
                case .name:
                    return 0.3
                case .syllabus:
                    return 0.1
            }
        }
    }
}
