//
//  SearchController.swift
//
//
//  Created by Erick Manaroulas Felipe on 28/10/21.
//

import Foundation
import Vapor

internal struct SearchController {
    static let shared = SearchController()

    private init() { }

    /// Parâmetros de busca textual.
    struct SearchParams: Content {
        let query: String
        let limit: Int?

        /// Limite de busca usado quando não especificado.
        static let defaultSearchLimit = 100
        /// Limite máximo de busca.
        static let maxSearchLimit = 1000

        var searchLimit: Int {
            min(self.limit ?? Self.defaultSearchLimit, Self.maxSearchLimit)
        }
    }

    func searchFor(_ req: Request) async throws -> [Match] {
        let params = try req.query.decode(SearchParams.self)
        guard params.searchLimit > 0 else {
            throw Abort(.badRequest)
        }
        // TODO: arrumar os argumentos de search de novo
        return try await self.search(on: req, for: params)
    }

    /// Busca textual dentre os dados carregados na memória.
    ///
    /// - Returns: Os `limit` melhores scores dentre todos os
    ///   os conjuntos de dados, mas com score menor que
    ///   `maxScore`.
    private func search(on req: Request, for params: SearchParams, maxScore: Double = 0.99) async throws -> [Match] {
        let limit = params.searchLimit
        let query = params.query

        let (elapsed, matches) = try await withTiming { () -> [Match] in
            async let disciplines = try await req.disciplines.search(for: query, limitedTo: limit, upTo: maxScore)
            async let courses = try await req.courses.search(for: query, limitedTo: limit, upTo: maxScore)
            return mergeAndSortSearchResults(results: try await [disciplines, courses], limitingTo: limit)
        }
        req.logger.info("Searched for \"\(query)\" with \(matches.count) results in \(elapsed) secs.")

        return matches
    }

    /// Junta vários resultados de busca em um só array.
    private func mergeAndSortSearchResults(results: [[Match]], limitingTo limit: Int) -> [Match] {
        var allResults = results.flatMap { $0 }
        allResults.sort { $0.score }
        return Array(allResults.prefix(limit))
    }
}
