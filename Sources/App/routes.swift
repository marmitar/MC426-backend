import Vapor


func routes(_ app: RoutesBuilder) throws {
    // Página principal: carrega o frontend
    app.get("") { req in
        getIndexHTML(for: req)
    }

    // endpoint para requisições da API
    api_routes(app.grouped("api"))

    // Fallback: deixa o frontend tratar
    app.get("**") { req in
        getIndexHTML(for: req)
    }
}

/// Carrega o HTML gerado pelo frontend.
private func getIndexHTML(for req: Request) -> Response {
    req.fileio.streamFile(at: "Public/index.html", mediaType: .html)
}

/// Rotas usadas pela API.
private func api_routes(_ api: RoutesBuilder) {
    // API: resposta padrão
    api.get("") { req -> Response in
        throw Abort(.noContent)
    }

    // API: busca textual entre vários elementos.
    api.get("busca") { req in
        try SearchController.shared.searchFor(req)
    }

    // API: dados para a página de uma disciplina
    api.get("disciplina", ":code") { req in
        try Discipline.Controller.shared.fetchDiscipline(req)
    }

    // API: dados para a página de um curso
    api.get("curso", ":code") { req in
        try Course.Controller.shared.fetchCourse(req)
    }

    // API: dados para a página de árvore do curso
    api.get("curso", ":code", ":variant") { req in
        try Course.Controller.shared.fetchCourseTree(req)
    }

    // API: desconhecida
    api.get("**") { req -> Response in
        throw Abort(.badRequest)
    }
}
