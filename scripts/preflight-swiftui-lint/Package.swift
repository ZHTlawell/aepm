// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PreflightSwiftUILint",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "preflight-swiftui-lint", targets: ["PreflightSwiftUILint"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .executableTarget(
            name: "PreflightSwiftUILint",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        )
    ]
)
