import Fuzz

/// Wrapper para fazzy matching de strings usando a biblioteca
/// [RapidFuzz](https://github.com/maxbachmann/rapidfuzz-cpp).
public final class FuzzyCached {
    /// Struct em C++ (com interface em C).
    private let cached: FuzzCachedRatio

    /// Constrói cache de `text` para comparação com outras
    /// strings.
    public init(_ text: String) {
        self.cached = fuzz_cached_init(text, text.utf8.count)
    }

    deinit {
        fuzz_cached_deinit(self.cached)
    }

    /// Compara a string no cache com `text`.
    ///
    /// - Returns: Score entre as strings que varia entre
    ///   0 (match perfeito) e 1 (completamente diferentes).
    public func ratio(to text: String) -> Double {
        fuzz_cached_ratio(self.cached, text, text.utf8.count)
    }
}
