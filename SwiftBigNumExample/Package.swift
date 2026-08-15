// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwiftBigNumExample",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/dankogai/swift-bignum.git", from: "6.3.1"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftBigNumExample",
            dependencies: [
                .product(name: "JSCBigInt", package: "swift-bigint-javascriptcore"),
                .product(name: "BigNum", package: "swift-bignum"),
            ]
        ),
    ]
)
