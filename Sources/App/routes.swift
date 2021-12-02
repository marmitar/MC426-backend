import Vapor


func routes(_ app: Application) throws {
    // Página principal: carrega o frontend
    app.get("") { req in
        getIndexHTML(for: req)
    }

    let api = app.grouped("api")

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

    // Fallback: deixa o frontend tratar
    app.get("**") { req in
        getIndexHTML(for: req)
    }
}

/// Carrega o HTML gerado pelo frontend.
private func getIndexHTML(for req: Request) -> Response {
    req.fileio.streamFile(at: "Public/index.html", mediaType: .html)
}
