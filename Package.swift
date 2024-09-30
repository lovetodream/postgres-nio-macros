// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "PreparedStatementsPostgresNIO",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "PostgresNIOMacros",
            targets: ["PostgresNIOMacros"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0-latest"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.0.0"),
    ],
    targets: [
        .macro(
            name: "PostgresNIOMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "PostgresNIOMacros",
            dependencies: [
                "PostgresNIOMacrosPlugin",
                .product(name: "PostgresNIO", package: "postgres-nio")
            ]
        ),
        .testTarget(
            name: "PostgresNIOMacrosTests",
            dependencies: [
                "PostgresNIOMacros",
                .product(name: "PostgresNIO", package: "postgres-nio")
            ]
        ),
        .testTarget(
            name: "PostgresNIOMacrosPluginTests",
            dependencies: [
                "PostgresNIOMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
