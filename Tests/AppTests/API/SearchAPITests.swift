@testable import App
import XCTVapor

final class SearchAPITests: XCTestCase {

    // MARK: - Montagem da URL do curso.

    /// Constrói a URL para busca incluindo parâmetros.
    private func url(for query: String, limit: String? = nil) -> String {
        var url = URL(string: "api/busca")!
        url = url.appending("query", value: query)
        if let limit = limit {
            url = url.appending("limit", value: limit)
        }

        return url.absoluteString
    }

    // MARK: - Testes

    func testSearchWithStringAsLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = url(for: "mc102", limit: "cinco")

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testSearchWithFloatAsLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = url(for: "mc102", limit: "10.0")

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testSearchWithEmptyQuery() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = url(for: "")

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

    //     let url = url(for: "mc102", limit: "-1")

    //     try app.test(.GET, url, afterResponse: { res in
    //         XCTAssertEqual(res.status, .badRequest)
    //     })
    // }

    func testSearchWithZeroLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let url = url(for: "mc102", limit: "0")

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testSearchWithValidDisciplineCodeAndLimit() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let limit = SearchController.maxSearchLimit - 100
        let url = url(for: "mc102", limit: "\(limit)")

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
        let url = url(for: "mc102", limit: "\(limit)")

        try app.test(.GET, url, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType, .json)
        })
    }

}
