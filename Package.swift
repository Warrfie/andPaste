// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CopyPaste",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CopyPaste", targets: ["CopyPaste"])
    ],
    targets: [
        .executableTarget(
            name: "CopyPaste",
            path: "Sources/CopyPaste"
        ),
        .testTarget(
            name: "CopyPasteTests",
            dependencies: ["CopyPaste"],
            path: "Tests/CopyPasteTests"
        )
    ]
)
