#include <string>
#include <rapidfuzz/fuzz.hpp>
#include <rapidfuzz/string_metric.hpp>

using rapidfuzz::common::BlockPatternMatchVector;
using rapidfuzz::common::PatternMatchVector;
using rapidfuzz::string_metric::detail::normalized_weighted_levenshtein;

extern "C" {
    #include "include/fuzz.h"

    // A interface em C deve ser equivalente, em bytes.
    static_assert(sizeof(FuzzCachedRatio::block) == sizeof(BlockPatternMatchVector),
        "Invalid description for FuzzCachedRatio::block, please update.");

    __attribute__((nonnull, leaf, nothrow))
    FuzzCachedRatio fuzz_cached_init(const uint8_t *str, size_t len) {
        FuzzCachedRatio cached;

        // tamanho da string no cache
        cached.buflen = len;
        // aloca nova string e copia conteúdo
        cached.buffer = (uint8_t *) malloc(len);
        memcpy(cached.buffer, str, len * sizeof(uint8_t));
        // inicializa o cache no espaço reservado
        new (&cached.block) BlockPatternMatchVector(
            std::basic_string_view(str, len)
        );
        return cached;
    }

    __attribute__((const, nonnull, leaf, nothrow))
    double fuzz_cached_ratio(const FuzzCachedRatio cached, const uint8_t *str, size_t len) {
        // usa o bloco do espaço reservado
        auto block = (BlockPatternMatchVector *) &cached.block;
        // e calcula o score com em rapidfuz::CachedRatio::ratio
        double score = normalized_weighted_levenshtein(
            std::basic_string_view(str, len),
            *block,
            std::basic_string_view(cached.buffer, cached.buflen),
            0.0
        );
        // adapta o valor
        return 1 - (score / 100);
    }

    __attribute__((leaf, nothrow))
    void fuzz_cached_deinit(FuzzCachedRatio cached) {
        // destrói o cache primeiro
        auto block = (BlockPatternMatchVector *) &cached.block;
        block->~BlockPatternMatchVector();
        // então desaloca a string
        free(cached.buffer);
    }
}
