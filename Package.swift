// swift-tools-version:5.9
import PackageDescription

// Paquet Swift : se compile avec `swift build` (Command Line Tools suffisent)
// et s'ouvre aussi directement dans Xcode. Le script scripts/construire-app.sh
// emballe l'exécutable dans un vrai bundle IleDynamique.app.
let package = Package(
    name: "IleDynamique",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "IleDynamique",
            path: "Sources/IleDynamique"
        )
    ]
)
