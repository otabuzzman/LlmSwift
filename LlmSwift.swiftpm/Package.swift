// swift-tools-version: 5.9

// WARNING:
// This file is automatically generated.
// Do not edit it by hand because the contents will be replaced.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "LlmSwift",
    platforms: [
        .iOS("17.4")
    ],
    products: [
        .iOSApplication(
            name: "LlmSwift",
            targets: ["AppModule"],
            bundleIdentifier: "com.otabuzzman.llmswift.ios",
            teamIdentifier: "28FV44657B",
            displayVersion: "1.1.8",
            bundleVersion: "20",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.yellow),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            appCategory: .education
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Bouke/Glob.git", "1.0.5"..<"2.0.0"),
        .package(url: "https://github.com/otabuzzman/CircularBuffer.git", "1.0.1"..<"2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "Glob", package: "Glob"),
                .product(name: "CircularBuffer", package: "CircularBuffer")
            ],
            path: ".",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
