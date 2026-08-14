// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "swift-bigint-javascriptcore",
    platforms: [
        .macOS(.v14), .iOS(.v17), .tvOS(.v17), .visionOS(.v1),
        // watchOS is excluded: JavaScriptCore is unavailable there.
    ],
    products: [
        .library(name: "JSCBigInt", targets: ["JSCBigInt"]),
    ],
    targets: [
        .target(name: "JSCBigInt"),
        .testTarget(name: "JSCBigIntTests", dependencies: ["JSCBigInt"]),
    ]
)
