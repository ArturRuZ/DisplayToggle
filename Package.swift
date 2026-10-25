// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DisplayToggle",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic (shortcuts, hotkey storage, strings) — covered by tests.
        .target(name: "DisplayToggleCore"),
        // The menu bar app itself: display control, Carbon hotkeys, UI.
        .executableTarget(name: "DisplayToggle", dependencies: ["DisplayToggleCore"]),
        .testTarget(name: "DisplayToggleCoreTests", dependencies: ["DisplayToggleCore"]),
    ]
)
