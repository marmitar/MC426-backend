// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "BackendProject",
    platforms: [
       .macOS(.v11)
    ],
    dependencies: [
        // framework para servidores web
        .package(url: "https://github.com/vapor/vapor.git", from: "4.53.0"),
        // parser de HTML para usar no web scraping
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.3")
    ],
    targets: [
        // o servidor propriamente
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .target(name: "RapidFuzz")
            ],
            cSettings: DefaultSettings.c,
            cxxSettings: DefaultSettings.cxx,
            swiftSettings: DefaultSettings.swift
        ),
        // executável que inicializa o servidor
        .executableTarget(
            name: "Run",
            dependencies: [
                .target(name: "App")
            ],
            cSettings: DefaultSettings.c,
            cxxSettings: DefaultSettings.cxx,
            swiftSettings: DefaultSettings.swift
        ),
        // integração com RapidFuzz
        .target(
            name: "RapidFuzz",
            exclude: ["rapidfuzz-cpp"],
            cSettings: DefaultSettings.c,
            cxxSettings: DefaultSettings.cxx + [
                .headerSearchPath("rapidfuzz-cpp"),
                // Modo de cálculo do score, usando uma das classes em
                // https://github.com/maxbachmann/rapidfuzz-cpp#readme
                .define("RATIO_TYPE", to: "CachedPartialRatio")
            ],
            swiftSettings: DefaultSettings.swift
        ),
        // testes do servidor
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor")
            ],
            cSettings: DefaultSettings.c,
            cxxSettings: DefaultSettings.cxx,
            swiftSettings: DefaultSettings.swift
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .gnu2x,
    cxxLanguageStandard: .gnucxx20
)

/// COnfigurações padrões de cada linguagem.
private enum DefaultSettings {
    static let swift: [SwiftSetting] = [
        // Detalhes em https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production
        .unsafeFlags(
            ["-O", "-remove-runtime-asserts", "-cross-module-optimization", "-whole-module-optimization"],
            .when(configuration: .release)
        ),
        .unsafeFlags(["-Onone", "-g"], .when(configuration: .debug))
    ]

    private static let warnings = [
        "-Wall", "-Wextra", "-Wpedantic"
    ]
    private static let optimizationFlags = [
        "-O3", "-march=native", "-mtune=native", "-pipe", "-fno-plt",
        "-ffast-math", "-fshort-enums", "-fno-exceptions"
    ]
    private static let debugFlags = ["-O1", "-ggdb3"]

    static let cxx: [CXXSetting] = [
        // habilita warnings e errors
        .unsafeFlags(warnings),
        .define("_FORTIFY_SOURCE", to: "1"),
        .unsafeFlags(debugFlags, .when(configuration: .debug)),
        // flags de otimização
        .define("NDEBUG", .when(configuration: .release)),
        .unsafeFlags(optimizationFlags, .when(configuration: .release))
    ]

    // swiftlint:disable identifier_name
    static let c: [CSetting] = [
        // habilita warnings e errors
        .unsafeFlags(warnings),
        .define("_FORTIFY_SOURCE", to: "1"),
        .unsafeFlags(debugFlags, .when(configuration: .debug)),
        // flags de otimização
        .define("NDEBUG", .when(configuration: .release)),
        .unsafeFlags(optimizationFlags, .when(configuration: .release))
    ]
}
