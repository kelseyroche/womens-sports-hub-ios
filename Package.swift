// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RallyKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RallyKit", targets: ["RallyKit"]),
    ],
    targets: [
        .target(name: "RallyKit"),
        .executableTarget(name: "RallyProbe", dependencies: ["RallyKit"]),
        .testTarget(name: "RallyKitTests", dependencies: ["RallyKit"]),
    ]
)
