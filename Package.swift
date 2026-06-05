// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Wispr",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "WisprLib",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/OpenWisprLib",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
            ]
        ),
        .executableTarget(
            name: "wispr",
            dependencies: ["WisprLib"],
            path: "Sources/OpenWispr"
        ),
        .testTarget(
            name: "WisprTests",
            dependencies: ["WisprLib"],
            path: "Tests/OpenWisprTests"
        ),
    ]
)
