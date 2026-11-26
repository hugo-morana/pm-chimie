// swift-tools-version: 5.9

// Projet « app » au format Swift Playgrounds : s'ouvre tel quel dans Xcode (Mac)
// ou dans Swift Playgrounds (iPad / Mac).

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "PM Chimie",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "PM Chimie",
            targets: ["AppModule"],
            bundleIdentifier: "fr.hugomorana.pmchimie",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
            supportedDeviceFamilies: [
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: ".",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
