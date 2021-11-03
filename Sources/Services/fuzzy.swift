import Foundation
import Fuzz

/// String preparada para comparação
/// e interoperabilidade com C.
struct QueryString {
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
        let text = from.normalized().splitWords().joined(separator: " ")

        self.content = ContiguousArray(text.utf8CString)
        self.length = self.content.withUnsafeBufferPointer {
            strlen($0.baseAddress!)
        }
    }

    /// Acessa o pointeiro e o tamanho da string,
    /// para trabalhar com C.
    func withUnsafePointer<R>(_ body: (UnsafePointer<CChar>, Int) throws -> R) rethrows -> R {
        try self.content.withUnsafeBufferPointer {
            try body($0.baseAddress!, self.length)
        }
    }
}

/// Wrapper para fazzy matching de strings usando a biblioteca
/// [RapidFuzz](https://github.com/maxbachmann/rapidfuzz-cpp).
final class FuzzyField: ScoreProvider {
    /// Struct em C++ (com interface em C).
    private var cached: FuzzCachedRatio

    /// Constrói cache de `value` para comparação com outras
    /// strings e calcula a norma do campo.
    @inlinable
    init(value: String) {
        let text = QueryString(value)

        // constroi com a API de C++
        self.cached = text.withUnsafePointer { pointer, _ in
            fuzz_cached_init(pointer)
        }
    }

    /// Precisa desalocar a memória em C++.
    @inlinable
    deinit {
        fuzz_cached_deinit(&self.cached)
    }

    /// Menor valor que para usar o partial ratio.
    private static let minScore = 0.01

    /// Compara a string no cache com `text`.
    ///
    /// - Returns: Score entre as strings que varia entre
    ///   0 (match perfeito) e 1 (completamente diferentes).
    @inlinable
    func score(for text: String) -> Double {
        let query = QueryString(text)
        let scoreValue = query.withUnsafePointer { ptr, len in
            fuzz_cached_ratio(self.cached, ptr, len)
        }
        // se o score for grande o bastante, então retorna ele
        if scoreValue > Self.minScore + Double.ulpOfOne {
            return scoreValue.clamped(upTo: 1.0)
        }

        // senão, calcula um novo score, usando levenshtein diretamente
        let newScore = query.withUnsafePointer { ptr, len in
            fuzz_levenshtein(self.cached.buffer, self.cached.buflen, ptr, len)
        }
        // garante o resultado no intervalo (ulpOfOne, minScore + ulpOfOne].
        return Double.ulpOfOne + Self.minScore * newScore.clamped(from: 0, upTo: 1.0)
    }
}
