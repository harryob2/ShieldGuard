// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShieldGuard",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ShieldGuardCore", targets: ["ShieldGuardCore"]),
        .executable(name: "ShieldGuardApp", targets: ["ShieldGuardApp"]),
    ],
    targets: [
        .target(
            name: "ShieldGuardCore"
        ),
        .executableTarget(
            name: "ShieldGuardApp",
            dependencies: ["ShieldGuardCore"],
            path: "Sources/ShieldGuardApp",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/ShieldGuardApp/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "ShieldGuardCoreTests",
            dependencies: ["ShieldGuardCore"]
        ),
    ]
)
