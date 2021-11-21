@testable import App
import XCTVapor

final class DisciplineAPITests: XCTestCase {

    /// URL básica de disciplina.
    private static let route = "api/disciplina/"

    func testFetchDisciplineWithValidCode() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = Self.route + "MC102"

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "{\"code\":\"MC102\",\"reqBy\":[\"CV074\",\"CV632\",\"EA044\",\"EA060\",\"EA869\",\"EA954\",\"EG940\",\"EM008\",\"EM024\",\"EQ048\",\"F 790\",\"FA103\",\"FA374\",\"MC202\",\"MC886\",\"MC886\",\"MC949\",\"MC949\",\"ME315\",\"MS211\",\"MS505\",\"MS614\"],\"syllabus\":\"Conceitos básicos de organização de computadores. Construção de algoritmos e sua representação em pseudocódigo e linguagens de alto nível. Desenvolvimento sistemático e implementação de programas. Estruturação, depuração, testes e documentação de programas. Resolução de problemas.\",\"name\":\"Algoritmos e Programação de Computadores\",\"credits\":6}")
        })
    }

    func testFetchDisciplineWithCodeCharacterCountBiggerThan5() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = Self.route + "MC1022"

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testFetchDisciplineWithCodeCharacterCountLowerThan5() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = Self.route + "MC10"

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testFetchDisciplineWithSpecialCasesCode() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = Self.route + "AA200"

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testFetchDisciplineWithLowerCaseCode() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = Self.route + "mc102"

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }
}
