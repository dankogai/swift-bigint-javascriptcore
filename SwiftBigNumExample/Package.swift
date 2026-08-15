// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwiftBigNumExample",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: ".."),
        // BigFloatOf<IntType> (generic BigFloat, dankogai/swift-bignum#31) is on
        // main but not yet in a release; switch to .upToNextMajor at the next tag
        .package(url: "https://github.com/dankogai/swift-bignum.git", branch: "main"),
    ],
    targets: [
        // the conformance glue: JSBigInt as a RationalElement and
        // BigIntegerType, plus the JSRat/JSFloat typealiases
        .target(
            name: "JSCBigNum",
            dependencies: [
                .product(name: "JSCBigInt", package: "swift-bigint-javascriptcore"),
                .product(name: "BigNum", package: "swift-bignum"),
            ]
        ),
        .executableTarget(name: "SwiftBigNumExample", dependencies: ["JSCBigNum"]),
        .testTarget(name: "JSCBigNumTests", dependencies: ["JSCBigNum"]),
    ]
)
