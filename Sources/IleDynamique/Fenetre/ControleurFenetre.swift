import AppKit
import Combine
import SwiftUI

/// Crée le panneau, le place en haut de l'écran choisi et suit la souris.
@MainActor
final class ControleurFenetre {
    private let viewModel: IleViewModel
    private let panneau: PanneauIle
    private var moniteurGlobal: Any?
    private var moniteurLocal: Any?
    private var abonnements = Set<AnyCancellable>()

    init(viewModel: IleViewModel) {
        self.viewModel = viewModel
        panneau = PanneauIle(cadre: NSRect(origin: .zero, size: Dimensions.taillePanneau))

        let hebergement = VueHebergement(rootView: VueIle(vm: viewModel))
        hebergement.sizingOptions = []
        panneau.contentView = hebergement

        viewModel.interactionChangee = { [weak self] sourisSurIle in
            self?.panneau.ignoresMouseEvents = !sourisSurIle
        }

        observerSysteme()
        installerMoniteursSouris()
        positionner()
    }

    func afficher() {
        panneau.orderFrontRegardless()
    }

    // MARK: - Placement

    private func positionner() {
        guard let ecran = GeometrieEncoche.ecranCible(identifiant: viewModel.preferences.identifiantEcran) else { return }
        viewModel.geometrie = GeometrieEncoche.pour(ecran: ecran)

        let cadreEcran = ecran.frame
        let taille = Dimensions.taillePanneau
        let cadre = NSRect(
            x: cadreEcran.midX - taille.width / 2,
            y: cadreEcran.maxY - taille.height,
            width: taille.width,
            height: taille.height
        )
        panneau.setFrame(cadre, display: true)
    }

    private func observerSysteme() {
        // Branchement / débranchement d'écran, changement de résolution.
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.positionner() }
            .store(in: &abonnements)

        // Changement d'écran dans les préférences.
        viewModel.preferences.$identifiantEcran
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.positionner() }
            .store(in: &abonnements)

        // Garde l'île visible après un changement de Space.
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in self?.panneau.orderFrontRegardless() }
            .store(in: &abonnements)
    }

    // MARK: - Souris

    /// Pas de minuteur : on réagit aux mouvements de souris envoyés par le système.
    /// Moniteur global = souris au-dessus des autres apps ; local = souris au-dessus de notre panneau.
    private func installerMoniteursSouris() {
        let masque: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        moniteurGlobal = NSEvent.addGlobalMonitorForEvents(matching: masque) { [weak self] _ in
            MainActor.assumeIsolated { self?.viewModel.evaluerSouris() }
        }
        moniteurLocal = NSEvent.addLocalMonitorForEvents(matching: masque) { [weak self] evenement in
            MainActor.assumeIsolated { self?.viewModel.evaluerSouris() }
            return evenement
        }
    }
}
