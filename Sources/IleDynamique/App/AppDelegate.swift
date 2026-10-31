import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: IleViewModel!
    private var controleurFenetre: ControleurFenetre!
    private var elementBarreMenus: NSStatusItem!
    private var fenetrePreferences: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = IleViewModel(preferences: .partagees)
        controleurFenetre = ControleurFenetre(viewModel: viewModel)
        configurerBarreMenus()
        viewModel.demarrer()
        controleurFenetre.afficher()
    }

    // MARK: - Barre des menus

    private func configurerBarreMenus() {
        elementBarreMenus = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let bouton = elementBarreMenus.button {
            bouton.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Île Dynamique")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Préférences…", action: #selector(ouvrirPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter Île Dynamique", action: #selector(quitter), keyEquivalent: "q"))
        for element in menu.items { element.target = self }
        elementBarreMenus.menu = menu
    }

    @objc private func ouvrirPreferences() {
        if fenetrePreferences == nil {
            let controleur = NSHostingController(rootView: VuePreferences(preferences: .partagees))
            let fenetre = NSWindow(contentViewController: controleur)
            fenetre.title = "Préférences"
            fenetre.styleMask = [.titled, .closable]
            fenetre.isReleasedWhenClosed = false
            fenetre.center()
            fenetrePreferences = fenetre
        }
        // Une app agent doit s'activer explicitement pour passer sa fenêtre au premier plan.
        NSApp.activate()
        fenetrePreferences?.makeKeyAndOrderFront(nil)
    }

    @objc private func quitter() {
        NSApp.terminate(nil)
    }
}
