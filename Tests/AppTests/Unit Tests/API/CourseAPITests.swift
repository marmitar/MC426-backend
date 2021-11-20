@testable import App
import XCTVapor

final class CourseAPITests: XCTestCase {
    func testFetchCourseWithVariantsAndValidCodeAndNoVariantSelected() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let route = "api/curso/"
        let course = "34/"

        try app.test(.GET, route + course, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "{\"name\":\"Engenharia de Computação - Integral\",\"variant\":[\"AA - Sistemas de Computação\",\"AB - Sistemas e Processos Industriais\",\"AX - Para Matrícula Antes da Opção\"],\"code\":\"34\"}")
        })
    }

    func testFetchCourseWithWithVariantsAndValidCodeAndValidVariant() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let route = "api/curso/"
        let course = "34/"
        let variant = "2/"

        try app.test(.GET, route + course + variant, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "[[\"F 128\",\"F 129\",\"HZ291\",\"MA111\",\"MA141\",\"MC102\",\"QG111\",\"QG122\"],[\"F 228\",\"F 229\",\"LA122\",\"MA211\",\"MA327\",\"MC202\"],[\"EA513\",\"F 315\",\"F 328\",\"F 329\",\"MA311\",\"MC322\"],[\"EA614\",\"EA772\",\"F 428\",\"F 429\",\"MC358\",\"MC404\"],[\"EA773\",\"EA871\",\"EA876\",\"EE400\",\"EE532\",\"MC458\",\"ME323\"],[\"EA202\",\"EA872\",\"EA960\",\"EE534\",\"EM423\",\"MS211\"],[\"EA074\",\"EA201\",\"EA616\",\"EA619\",\"EA979\"],[\"BE310\",\"EA072\",\"EA080\",\"EA721\",\"EA722\",\"EG950\"],[\"CE304\",\"CE838\",\"EA006\",\"EA044\",\"EE610\"],[\"CE738\"]]")
        })
    }

    func testFetchCourseWithWithVariantsAndValidCodeAndInvalidVariant() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let route = "api/curso/"
        let course = "34/"
        let variant = "3/"

        try app.test(.GET, route + course + variant, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }


    func testFetchCourseWithInvalidCodeAndNoVariantSelected() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let route = "api/curso/"
        let course = "0/"

        try app.test(.GET, route + course, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testFetchCourseWithInvalidCodeAndAnyVariantSelected() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let route = "api/curso/"
        let course = "0/"
        let variant = "7/"

        try app.test(.GET, route + course + variant, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testFetchCourseWithValidCodeAndNoVariantSelected() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let route = "api/curso/"
        let course = "11/"
        let variant = ""

        try app.test(.GET, route + course + variant, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "{\"name\":\"Engenharia Elétrica - Integral\",\"code\":\"11\"}")
        })
    }

    func testFetchCourseWithValidCodeAndValidVariantSelected() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let route = "api/curso/"
        let course = "11/"
        let variant = "0"

        try app.test(.GET, route + course + variant, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "[[\"EA772\",\"EM230\",\"EM312\",\"F 128\",\"F 129\",\"MA111\",\"MA141\"],[\"EA513\",\"EA773\",\"F 228\",\"F 229\",\"MA211\",\"MA327\",\"MC102\"],[\"EA611\",\"EA869\",\"EE103\",\"EM524\",\"F 315\",\"MA311\",\"ME323\"],[\"EA871\",\"EE300\",\"EE301\",\"EE400\",\"EE521\",\"LA122\",\"MS211\",\"QG111\",\"QG122\"],[\"EA075\",\"EA614\",\"EE410\",\"EE522\",\"EE540\",\"EM423\",\"ET520\",\"ET521\"],[\"EA616\",\"EA619\",\"EA879\",\"EE530\",\"EE754\",\"EE881\",\"ET620\",\"ET621\"],[\"EA076\",\"EA721\",\"EA722\",\"EE531\",\"EE640\",\"EE755\",\"EE882\",\"ET720\",\"ET911\"],[\"CE738\",\"CE838\",\"EA044\",\"EE610\",\"EE641\",\"EE833\"],[\"BE310\",\"CE304\",\"EA006\"],[]]")
        })
    }

    func testFetchCourseWithValidCodeAndInvalidVariantSelected() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        let route = "api/curso/"
        let course = "11/"
        let variant = "1"

        try app.test(.GET, route + course + variant, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }
}
