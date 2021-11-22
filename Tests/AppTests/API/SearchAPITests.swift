@testable import App
import XCTVapor

final class SearchAPITests: XCTestCase {

    // MARK: - Constantes

    /// URL básica de busca.
    private static let route = "api/busca"

    // MARK: - Testes

    func testSearchWithStringAsLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = searchUrl(for: "mc102", limit: "cinco")

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testSearchWithFloatAsLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = searchUrl(for: "mc102", limit: "10.0")

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testSearchWithEmptyQuery() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = searchUrl(for: "")

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType, .json)
            XCTAssertJSON(text: res.body.string, matches: [])
        })
    }

    // func testSearchWithNegativeLimit() throws {
    //     let app = Application(.testing)
    //     defer { app.shutdown() }
    //     try configure(app)

    //     let url = searchUrl(for: "mc102", limit: "-1")

    //     try app.test(.GET, url, afterResponse: { res in
    //         XCTAssertEqual(res.status, .badRequest)
    //     })
    // }

    func testSearchWithZeroLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = searchUrl(for: "mc102", limit: "0")

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testSearchWithValidDisciplineCodeAndLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let limit = SearchController.maxSearchLimit - 100
        let url = searchUrl(for: "mc102", limit: "\(limit)")

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType, .json)
        })
    }

    func testSearchWithValidDisciplineCodeAndHugeLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let limit = SearchController.maxSearchLimit + 100
        let url = searchUrl(for: "mc102", limit: "\(limit)")

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType, .json)
        })
    }

    // MARK: - Métodos Auxiliares

    /// Monta a URL de busca incluindo os parâmetros.
    private func searchUrl(for query: String, limit: String? = nil) -> String {
        var url = URL(string: Self.route)!
        url = url.appending("query", value: query)
        if let limit = limit {
            url = url.appending("limit", value: limit)
        }

        return url.absoluteString
    }

}
