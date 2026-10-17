// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacReady",
    platforms: [.macOS("13.5")],
    products: [
        .library(name: "MacStateCore", targets: ["MacStateCore"]),
        .executable(name: "macready", targets: ["MacReadyCLI"])
    ],
    targets: [
        .target(name: "SMCBridge", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "MacStateCore", dependencies: ["SMCBridge"]),
        .executableTarget(name: "MacReadyCLI", dependencies: ["MacStateCore"]),
        .testTarget(name: "MacStateCoreTests", dependencies: ["MacStateCore", "MacReadyCLI"])
    ],
    swiftLanguageVersions: [.v5]
)
