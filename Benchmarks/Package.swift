// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "bench",
            dependencies: [
                .product(name: "JSCBigInt", package: "swift-bigint-javascriptcore"),
                .product(name: "BigInt", package: "BigInt"),
            ]
        ),
    ]
)
