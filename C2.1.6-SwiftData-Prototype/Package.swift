// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftDataGenerationPrototype",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SwiftDataGenerationPrototype", targets: ["SwiftDataGenerationPrototype"])
    ],
    targets: [
        .target(name: "SwiftDataGenerationPrototype"),
        .testTarget(
            name: "SwiftDataGenerationPrototypeTests",
            dependencies: ["SwiftDataGenerationPrototype"]
        )
    ]
)
