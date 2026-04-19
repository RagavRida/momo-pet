// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MomoPet",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MomoPet",
            path: "Sources/MomoPet"
        )
    ]
)
