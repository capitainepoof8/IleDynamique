import AppKit

/// Point d'entrée : application « agent » (pas d'icône dans le Dock).
@main
enum Principal {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegue = AppDelegate()
        application.delegate = delegue
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegue) {
            application.run()
        }
    }
}
