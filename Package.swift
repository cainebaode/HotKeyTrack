// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HotKeyTrack",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HotKeyTrack", targets: ["HotKeyTrack"])
    ],
    targets: [
        .executableTarget(
            name: "HotKeyTrack",
            path: "Sources/HotKeyTrack"
        )
    ]
)
