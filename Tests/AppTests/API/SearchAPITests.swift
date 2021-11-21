@testable import App
import XCTVapor

final class SearchAPITests: XCTestCase {

    private static let route = "api/busca"

    /// Provide the search URL including parameters.
    private func searchUrl(for query: String, limit: Int? = nil) -> String {
        var url = URL(string: Self.route)!
        url = url.appending("query", value: query)
        if let limit = limit {
            url = url.appending("limit", value: "\(limit)")
        }

        return url.absoluteString
    }

}
