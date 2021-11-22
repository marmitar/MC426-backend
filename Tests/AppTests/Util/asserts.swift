import App
import XCTVapor

/// Checa se o acesso no endpoint do servidor retorna o resultado esperado em JSON.
func assertJsonResult(
    on endpoint: String,
    matches expectedValue: JSONValue,
    environment: Environment = .testing
) throws {
    let app = Application(environment)
    defer { app.shutdown() }
    try configure(app)

    try app.test(.GET, endpoint, afterResponse: { res in
        XCTAssertEqual(res.status, .ok)
        XCTAssertEqual(res.content.contentType, .json)
        XCTAssertJSON(text: res.body.string, matches: expectedValue)
    })
}

/// Assegura que o endpoint não existe no servidor.
func assertNotFound(
    on endpoint: String,
    environment: Environment = .testing)
throws {
    let app = Application(environment)
    defer { app.shutdown() }
    try configure(app)

    try app.test(.GET, endpoint, afterResponse: { res in
        XCTAssertEqual(res.status, .notFound)
    })
}
