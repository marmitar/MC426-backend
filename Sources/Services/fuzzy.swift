import Foundation
import Fuzz

/// String preparada para comparação
/// e interoperabilidade com C.
public struct QueryString {
    /// Conteúdo da string em forma de buffer para
    /// trabalhar com a API de C.
    private let content: ContiguousArray<CChar>
    /// Tamanho do buffer, desconsiderando o byte null.
    private let length: Int

    /// Prepara a string para comparação e para
    /// funcionar com a API de C.
    ///
    /// A string é prepara padronizando ela (apenas
    /// um espaço entre palavras) e normalizando
    /// (removendo acentos e padronizando caracteres
    /// unicode).
    init(_ from: String) {
        let (text, _) = Self.prepareAndCountWords(from)

        self.content = ContiguousArray(text.utf8CString)
        self.length = self.content.withUnsafeBufferPointer {
            strlen($0.baseAddress!)
        }
    }

    /// Acessa o pointeiro e o tamanho da string,
    /// para trabalhar com C.
    fileprivate func withUnsafePointer<R>(_ body: (UnsafePointer<CChar>, Int) throws -> R) rethrows -> R {
        try self.content.withUnsafeBufferPointer {
            try body($0.baseAddress!, self.length)
        }
    }

    /// Faz a normalização descrita em `init`
    /// e conta a quantidade de palavras com
    /// mais de 2 caracteres.
    fileprivate static func prepareAndCountWords(_ string: String) -> (text: String, words: Int) {
        let words = string.normalized().splitWords().filter { $0.count > 2 }

        return (text: words.joined(separator: " "), words: words.count)
    }
}

/// Cache dos campos de uma estrutura ou classe
/// usados para comparação com uma string de
/// busca usando fuzzy matching.
struct FuzzyCache {
    /// Campos no cache.
    private let fields: [FuzzyField]

    /// Inicializa cache com lista de campos da
    /// struct e função que extrai valor textual
    /// e peso do campo.
    ///
    /// Peso já deve estar normalizado.
    @inlinable
    init<S: Sequence>(fields: S, getter: (S.Element) -> (value: String, weight: Double)) {
        self.fields = fields.map { field in
            let (value, weight) = getter(field)
            return FuzzyField(value, weight)
        }
    }

    /// Score combinado dos campos da struct para a string de busca.
    ///
    /// - Returns: Score entre da struct que varia entre
    ///   0 (match perfeito) e 1 (completamente diferentes).
    @inlinable
    func fullScore(for query: QueryString) -> Double {
        // de https://github.com/krisk/Fuse/blob/master/src/core/computeScore.js
        return self.fields.reduce(1.0) { (totalScore, field) in
            let score = field.score(for: query)
            return totalScore * pow(score, field.weight * field.norm)
        }
    }
}

/// Wrapper para fazzy matching de strings usando a biblioteca
/// [RapidFuzz](https://github.com/maxbachmann/rapidfuzz-cpp).
private final class FuzzyField {
    /// Struct em C++ (com interface em C).
    private var cached: FuzzCachedRatio
    /// Peso associado ao campo, para combinação de scores.
    let weight: Double
    /// Norma do campo, para combinação de scores.
    let norm: Double

    /// Constrói cache de `value` para comparação com outras
    /// strings e calcula a norma do campo.
    @inlinable
    init(_ value: String, _ weight: Double) {
        let (text, words) = QueryString.prepareAndCountWords(value)

        self.weight = weight
        // constroi com a API de C++
        self.cached = text.withCString { fuzz_cached_init($0) }
        // norma baseada em https://github.com/krisk/Fuse/blob/master/src/tools/norm.js
        self.norm = 1 / Double(words).squareRoot()
    }

    /// Precisa desalocar a memória em C++.
    @inlinable
    deinit {
        fuzz_cached_deinit(&self.cached)
    }

    /// Compara a string no cache com `text`.
    ///
    /// - Returns: Score entre as strings que varia entre
    ///   0 (match perfeito) e 1 (completamente diferentes).
    @inlinable
    func score(for query: QueryString) -> Double {
        let scoreValue = query.withUnsafePointer { ptr, len in
            fuzz_cached_ratio(self.cached, ptr, len)
        }
        // garante o valor entre 0 e 1
        if scoreValue <= 0 {
            return 0.0
        } else if scoreValue >= 1 {
            return 1.0
        } else {
            return scoreValue
        }
    }
}
