import AppKit
import SwiftUI

/// Panneau transparent, sans bordure et non activant qui flotte au-dessus de la barre des menus.
final class PanneauIle: NSPanel {
    init(cadre: NSRect) {
        super.init(
            contentRect: cadre,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        // Par défaut les clics traversent le panneau ; on ne les capte que quand la souris est sur l'île.
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Empêche AppKit de repousser la fenêtre sous la barre des menus.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Vue d'hébergement SwiftUI qui accepte le premier clic (panneau jamais « actif »).
final class VueHebergement<Contenu: View>: NSHostingView<Contenu> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
