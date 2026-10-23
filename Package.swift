// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoiceInput",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VoiceInputCore", targets: ["VoiceInputCore"]),
        .executable(name: "VoiceInput", targets: ["VoiceInput"]),
    ],
    targets: [
        .target(name: "VoiceInputCore"),
        .executableTarget(name: "VoiceInput", dependencies: ["VoiceInputCore"]),
        .testTarget(name: "VoiceInputCoreTests", dependencies: ["VoiceInputCore"]),
    ],
    swiftLanguageModes: [.v6]
)
