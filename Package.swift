// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Reclaim",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "reclaim-scanner", targets: ["ReclaimScanner"]),
        .executable(name: "ReclaimApp", targets: ["ReclaimApp"])
    ],
    targets: [
        .target(
            name: "ReclaimCore",
            path: "Sources/ReclaimCore"
        ),
        .executableTarget(
            name: "ReclaimScanner",
            dependencies: ["ReclaimCore"],
            path: "Sources/ReclaimScanner"
        ),
        .executableTarget(
            name: "ReclaimApp",
            dependencies: ["ReclaimCore"],
            path: "Sources/ReclaimApp"
        )
    ]
)
