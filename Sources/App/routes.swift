import Vapor

func routes(_ app: Application) throws {
    let api = app.grouped("api")

    // API: busca textual entre vários elementos.
    api.get("busca") { req in
        try await SearchController.shared.searchFor(req)
    }

    // API: dados para a página de uma disciplina
    api.get("disciplina", ":code") { req in
        try await req.disciplines.fetchDiscipline(req)
    }

    // API: dados para a página de um curso
    api.get("curso", ":code") { req in
        return try await req.courses.fetchCourse(req)
    }

    // API: dados para a página de árvore do curso
    api.get("curso", ":code", ":variant") { req in
        return try await req.courses.fetchCourseTree(req)
    }
}
