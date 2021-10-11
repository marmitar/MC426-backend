import Foundation
import Logging

/// Dado (struct ou classe) com campos procuráveis.
public protocol Searchable {
    /// Propriedades procuráveis do tipo.
    associatedtype Properties: SearchableProperty where Properties.Of == Self
    /// Propriedade usada para ordenadação.
    ///
    /// O padrão é `nil`.
    static var sortOn: Properties? { get }
}

public extension Searchable {
    static var sortOn: Properties? { nil }

    /// Coleção de propriedades do dado.
    static var properties: Properties.AllCases {
        Properties.allCases
    }
}

/// Enum das propriedades procuráveis de um dado.
public protocol SearchableProperty: CaseIterable, Equatable {
    /// Tipo do dado procurável.
    associatedtype Of: Searchable

    /// Acesso da propriedade do dado.
    func getter(_ item: Of) -> String

    /// Peso da propriedade (1.0, por padrão).
    ///
    /// Deve ser estritamente positivo.
    var weight: Double { get }
}

public extension SearchableProperty {
    var weight: Double { 1.0 }
}

/// Conjunto imutável de um mesmo tipo de dados procuráveis.
public struct Database<Item: Searchable> {
    /// Campos procuráveis do dado.
    public typealias Field = Item.Properties
    /// Campo de ordenação.
    static var sortedOn: Field? { Item.sortOn }
    /// Par struct e sua cache de fuzzy matching.
    private typealias Entry = (item: Item, cache: FuzzyCache)

    /// Conjunto de dados.
    private let entries: [Entry]

    /// Prepara os dados para busca.
    ///
    /// `Item` não deve conter pesos negativos.
    private static func buildEntries(for data: [Item]) -> [Entry] {
        // soma dos pesos para normalização
        let totalWeight = Item.properties.reduce(0) { $0 + $1.weight }

        /// monta cache de cada dado
        var entries = data.concurrentMap { item -> Entry in
            let cache = FuzzyCache(fields: Item.properties) {
                ($0.getter(item), $0.weight / totalWeight)
            }
            return (item, cache)
        }
        // ordena se requisitado
        if let field = Item.sortOn {
            entries.sort { field.getter($0.item) }
        }
        return entries
    }

    /// Constrói banco de dados na memória com cache de busca.
    public init(entries data: [Item], logger: Logger? = nil) throws {
        // garante pesos positivos
        if Item.properties.contains(where: { $0.weight <= 0 }) {
            throw NonPositiveWeightError(Item.self)
        }
        // só então monta os dados
        logger?.info("Buildind Database for \"\(Item.self)\"...")

        let (elapsed, entries) = withTiming {
            Self.buildEntries(for: data)
        }
        self.entries = entries

        logger?.info("DB built with \(data.count) items in \(elapsed) secs.")

    }

    /// Busca linear no conjunto de dados.
    ///
    /// - Returns: Primeiro elemento no conjunto de dados
    ///   que retorna `true` para o predicado.
    public func find(where predicate: (Item) throws -> Bool) rethrows -> Item? {
        try entries.first { try predicate($0.item) }?.item
    }

    /// Busca por um dos campos do dado.
    ///
    /// - Returns: Algum elemento no conjunto de dados
    ///   com `field.getter(element) == value`.
    ///
    /// Executa busca binário quando o campo é base de ordenação
    /// (`Searchable.sortOn`) e busca linear nos outros casos.
    public func find(_ field: Field, equals value: String) -> Item? {
        if field == Self.sortedOn {
            return entries.binarySearch(for: value) { field.getter($0.item) }
                .flatMap { result in
                    // garante que o elemento tem chave certa
                    if field.getter(result.item) == value {
                        return result.item
                    } else {
                        return nil
                    }
                }
        } else {
            return entries.first { (item, _) in
                field.getter(item) == value
            }?.item
        }
    }

    public func search(_ query: QueryString, limit: Int? = nil) -> ArraySlice<(item: Item, score: Double)> {
        var scored = self.entries.concurrentMap { (item, cache) in
            (item: item, score: cache.fullScore(for: query))
        }
        scored.sort(on: { $0.score })

        if let limit = limit {
            return scored.prefix(limit)
        } else {
            return scored[...]
        }
    }

    public func search(_ text: String, limit: Int? = nil) -> ArraySlice<(item: Item, score: Double)> {
        self.search(QueryString(text), limit: limit)
    }
}

/// Erro para tipos `Searchable` mas com peso negativo ou zero.
private struct NonPositiveWeightError: Error, LocalizedError {
    /// Todas as propriedades do tipo defeituoso.
    private let properties: [(name: String, weight: Double)]
    /// Tipo com problema de peso não-positivo.
    private let type: Any.Type

    /// Constrói erro para tipos buscáveis.
    init<T: Searchable>(_ type: T.Type) {
        self.type = type

        self.properties = T.properties.map { field in
            (name: "\(field)", field.weight)
        }
    }

    /// Propriedades formatadas para impressão.
    private var formattedFields: [String] {
        self.properties.map { (name, weight) in
            "\(name) (\(weight))"
        }
    }

    /// Propriedades com peso não-positivo.
    private var offendingFields: [String] {
        self.properties.compactMap { (name, weight) in
            if weight <= 0 {
                return name
            } else {
                return nil
            }
        }
    }

    var errorDescription: String? {
        "Searchable type '\(type)' contains non-positive weights."
    }

    var failureReason: String? {
        "Type '\(type)' with fields \(formattedFields) contains"
        + " \(offendingFields.count) negative weights"
    }

    var recoverySuggestion: String? {
        "Fix weight for fields: \(offendingFields.joined(separator: ", "))"
    }
}
