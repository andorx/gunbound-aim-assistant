// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GunboundAimAssistant",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "GunboundAimAssistant",
            targets: ["GunboundAimAssistant"]
        )
    ],
    targets: [
        .executableTarget(
            name: "GunboundAimAssistant",
            path: "Sources",
            sources: [
                "Models/WindSettings.swift",
                "Models/MarkerPair.swift",
                "Models/TrajectoryPoint.swift",
                "Physics/TrajectoryCalculator.swift",
                "Utilities/ColorInterpolation.swift",
                "Utilities/WindowFinder.swift",
                "UI/CircularKnob.swift",
                "UI/TrajectoryView.swift",
                "Windows/ControlPanelWindow.swift",
                "Windows/OverlayWindow.swift",
                "App/AppDelegate.swift",
                "App/main.swift"
            ],
            resources: [
                .process("../Assets.xcassets")
            ]
        )
    ]
)
