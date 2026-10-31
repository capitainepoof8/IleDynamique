import AppKit
import EventKit

struct EvenementResume: Equatable {
    let titre: String
    let debut: Date
    let fin: Date
    let journeeEntiere: Bool
    let couleur: NSColor
}

/// Prochain événement des 7 prochains jours (EventKit).
@MainActor
final class ModuleCalendrier: ObservableObject {
    enum EtatAutorisation {
        case enAttente
        case autorise
        case refuse
    }

    @Published private(set) var prochain: EvenementResume?
    @Published private(set) var autorisation = EtatAutorisation.enAttente

    private let magasin = EKEventStore()
    private var estDemarre = false

    func demarrer() {
        guard !estDemarre else { return }
        estDemarre = true

        // Le système nous prévient quand un calendrier change : inutile de relire en boucle.
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: magasin, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rafraichir() }
        }

        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            autorisation = .autorise
            rafraichir()
        case .notDetermined:
            Task {
                let accorde = (try? await magasin.requestFullAccessToEvents()) ?? false
                autorisation = accorde ? .autorise : .refuse
                rafraichir()
            }
        default:
            autorisation = .refuse
        }
    }

    func rafraichir() {
        guard autorisation == .autorise else { return }
        let maintenant = Date()
        guard let limite = Calendar.current.date(byAdding: .day, value: 7, to: maintenant) else { return }

        let predicat = magasin.predicateForEvents(withStart: maintenant, end: limite, calendars: nil)
        let evenements = magasin.events(matching: predicat)
            .filter { $0.endDate > maintenant }
            .sorted { $0.startDate < $1.startDate }

        // On privilégie un événement horaire plutôt qu'un événement « toute la journée ».
        let choisi = evenements.first(where: { !$0.isAllDay }) ?? evenements.first
        prochain = choisi.map { evenement in
            EvenementResume(
                titre: evenement.title ?? "Sans titre",
                debut: evenement.startDate,
                fin: evenement.endDate,
                journeeEntiere: evenement.isAllDay,
                couleur: evenement.calendar.map { NSColor(cgColor: $0.cgColor) ?? .systemBlue } ?? .systemBlue
            )
        }
    }
}
