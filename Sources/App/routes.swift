import Vapor

func routes(_ app: Application) throws {
    let api = app.grouped("api")

    /// Parâmetros de busca.
    struct SearchParams: Content {
        let query: String
        let limit: Int?
    }

    // API: busca textual entre vários elementos.
    api.get("busca") { req -> [Discipline] in
        let params = try req.query.decode(SearchParams.self)

        return req.scrapedData.search(
            for: params.query,
            limitingTo: params.limit
        )
    }

    // API: dados para a página de uma disciplina
    api.get("disciplina", ":code") { req -> Discipline in
        // SAFETY: o router do Vapor só deixa chegar aqui com o parâmetro
        let code = req.parameters.get("code")!

        guard let result = req.scrapedData.getDiscipline(with: code) else {
            // retorna 404 NOT FOUND
            throw Abort(.notFound)
        }
        return result
    }
}
