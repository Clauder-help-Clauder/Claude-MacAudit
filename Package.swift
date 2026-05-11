// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacAudit",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
    ],
    targets: [
        // CLI executable
        .executableTarget(
            name: "MacAudit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "MacAuditCore"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        // Shared core — models, modules, executor
        .target(
            name: "MacAuditCore",
            path: "Sources/MacAuditCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        // SwiftUI views + design system — framework target，支持 Xcode Preview
        .target(
            name: "MacAuditUI",
            dependencies: ["MacAuditCore"],
            path: "Sources/MacAuditUI",
            exclude: ["App/MacAuditApp.swift"],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        // Thin launcher — @main entry point，依赖 MacAuditUI framework
        .executableTarget(
            name: "MacAuditApp",
            dependencies: ["MacAuditUI"],
            path: "Sources/MacAuditApp",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "MacAuditTests",
            dependencies: [
                "MacAudit",
                "MacAuditCore",
                "MacAuditUI",
                .product(name: "Testing", package: "swift-testing"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
