import Foundation
import Services
import Vapor


typealias CourseTree = [[String]]

/// Representação de um curso.
struct Course: Content {
    /// Código do curso.
    let code: String
    /// Nome do curso.
    let name: String
    /// Modalidades, se houver, ou a árvore do curso.
    let content: CourseContent

    /// Representa as modalidades ou a árvore do curso.
    enum CourseContent: Codable {
        case variants([Variant])
        case tree(CourseTree)
    }
}

/// Representa uma modalidade de um curso.
struct Variant: Content {
    /// Nome da modalidade. Vazio se é árvore sem modalidade.
    let name: String
    /// Árvore da modalidade.
    let tree: CourseTree
}

extension Course: WebScrapable {
    static let scriptName = "courses.py"
    typealias Output = Self
}

extension Course: Searchable {
    /// Ordena por nome, para buscar mais rápido.
    static let sortOn: Properties? = .code

    /// Propriedades buscáveis no curso.
    enum Properties: SearchableProperty {
        /// Busca por código.
        case code
        /// Busca por nome.
        case name

        @inlinable
        func get(from item: Course) -> String {
            switch self {
            case .code:
                return item.code
            case .name:
                return item.name
            }
        }
    }
}

extension Course: Matchable {
    /// Forma reduzida, com código e nome.
    struct ReducedForm: Encodable {
        let code: String
        let name: String
    }

    @inlinable
    func reduced() -> ReducedForm {
        .init(code: self.code, name: self.name)
    }
}

extension Course: Decodable {
    /// Checa se existem modalidades e árvore de curso e retorna o conteúdo correspondente.
    /// No caso de haver nenhum ou ambos, lança o erro correspondente.
    static private func checkVariantsAndTree(variants: [Variant]?, tree: CourseTree?) throws -> CourseContent {
        switch (variants, tree) {
            case (nil, nil):
                throw CourseContentError.treeNorVariantPresent
            case (.some, .some):
                throw CourseContentError.treeAndVariantPresent
            case (.some(let variants), nil):
                return CourseContent.variants(variants)
            case (nil, .some(let tree)):
                return CourseContent.tree(tree)
        }
    }

    /// Chaves para ler o json criado por scrape.
    private enum Keys: String, CodingKey {
        case code
        case name
        case variant
        case tree
    }

    /// Monta um curso a partir do json de scrape.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: Keys.self)

        // Pega o código e nome do curso.
        code = try values.decode(String.self, forKey: .code)
        name = try values.decode(String.self, forKey: .name)

        // Tenta montar o conteúdo a partir de `variant` e `tree`.
        let variants = try? values.decode([Variant].self, forKey: .variant)
        let tree = try? values.decode(CourseTree.self, forKey: .tree)
        content = try Self.checkVariantsAndTree(variants: variants, tree: tree)
    }

}

/// Representa os erros de conteúdo de um curso.
private enum CourseContentError: Error {
    // Tanto árvore do curso como modalidades presentes.
    case treeAndVariantPresent
    // Nem árvore nem modalidade presentes.
    case treeNorVariantPresent
}
