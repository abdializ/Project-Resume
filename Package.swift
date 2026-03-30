// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProjectResume",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ProjectResumeKit",
            targets: ["ProjectResumeKit"]
        ),
        .library(
            name: "ProjectResumeWidgetSupport",
            targets: ["ProjectResumeWidgetSupport"]
        ),
        .executable(
            name: "ProjectResume",
            targets: ["ProjectResumeExecutable"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .target(
            name: "ProjectResumeKit",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/ProjectResume",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "ProjectResumeWidgetSupport",
            path: "Sources/ProjectResumeWidgetSupport"
        ),
        .executableTarget(
            name: "ProjectResumeExecutable",
            dependencies: [
                "ProjectResumeKit"
            ]
            ,
            path: "Sources/ProjectResumeExecutable"
        )
    ]
)
