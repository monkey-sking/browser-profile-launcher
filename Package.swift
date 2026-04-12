// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "browser-profile-launcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "BrowserProfileLauncher",
            targets: ["browser-profile-launcher"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "browser-profile-launcher"
        ),
        .testTarget(
            name: "browser-profile-launcherTests",
            dependencies: ["browser-profile-launcher"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
