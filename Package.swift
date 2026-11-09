// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "FloatKitchen",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "FloatKitchen", targets: ["FloatKitchen"])],
    targets: [
        .target(name: "KitchenCore"),
        .executableTarget(name: "FloatKitchen", dependencies: ["KitchenCore"], resources: [.copy("Assets")], linkerSettings: [.linkedFramework("AppKit")]),
        .executableTarget(name: "KitchenCoreChecks", dependencies: ["KitchenCore"], path: "Tests/KitchenCoreChecks")
    ]
)
