// swift-tools-version: 6.0
import PackageDescription

// Runs calculation regression tests independently of the iOS app target.
let package = Package(
    name: "KDPICalculatorLogic",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "KDPICore",
            path: "KDPICalculator",
            exclude: ["Assets.xcassets", "ContentView.swift", "KDPICalculatorApp.swift", "KDPITimeMachineView.swift"],
            sources: ["KDPICalculator.swift", "KDPIMappingTables.swift"]
        ),
        .testTarget(name: "KDPICoreTests", dependencies: ["KDPICore"], path: "Tests")
    ]
)
