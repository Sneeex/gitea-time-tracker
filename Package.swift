// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GiteaTimeTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GiteaTimeTracker", targets: ["GiteaTimeTracker"])
    ],
    targets: [
        .executableTarget(
            name: "GiteaTimeTracker",
            path: "Sources"
        ),
        .testTarget(
            name: "GiteaTimeTrackerTests",
            dependencies: ["GiteaTimeTracker"],
            path: "Tests"
        ),
    ]
)
