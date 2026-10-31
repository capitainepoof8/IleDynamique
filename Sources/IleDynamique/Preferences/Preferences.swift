import Foundation

/// Réglages de l'utilisateur, enregistrés dans UserDefaults.
@MainActor
final class Preferences: ObservableObject {
    static let partagees = Preferences()

    private enum Cle {
        static let musique = "moduleMusique"
        static let batterie = "moduleBatterie"
        static let niveaux = "moduleNiveaux"
        static let calendrier = "moduleCalendrier"
        static let etagere = "moduleEtagere"
        static let ecran = "identifiantEcran"
    }

    @Published var moduleMusique: Bool {
        didSet { UserDefaults.standard.set(moduleMusique, forKey: Cle.musique) }
    }
    @Published var moduleBatterie: Bool {
        didSet { UserDefaults.standard.set(moduleBatterie, forKey: Cle.batterie) }
    }
    @Published var moduleNiveaux: Bool {
        didSet { UserDefaults.standard.set(moduleNiveaux, forKey: Cle.niveaux) }
    }
    @Published var moduleCalendrier: Bool {
        didSet { UserDefaults.standard.set(moduleCalendrier, forKey: Cle.calendrier) }
    }
    @Published var moduleEtagere: Bool {
        didSet { UserDefaults.standard.set(moduleEtagere, forKey: Cle.etagere) }
    }
    /// 0 = automatique (écran avec encoche, sinon écran principal).
    @Published var identifiantEcran: Int {
        didSet { UserDefaults.standard.set(identifiantEcran, forKey: Cle.ecran) }
    }

    private init() {
        let defauts = UserDefaults.standard
        defauts.register(defaults: [
            Cle.musique: true,
            Cle.batterie: true,
            Cle.niveaux: true,
            Cle.calendrier: true,
            Cle.etagere: true,
            Cle.ecran: 0,
        ])
        moduleMusique = defauts.bool(forKey: Cle.musique)
        moduleBatterie = defauts.bool(forKey: Cle.batterie)
        moduleNiveaux = defauts.bool(forKey: Cle.niveaux)
        moduleCalendrier = defauts.bool(forKey: Cle.calendrier)
        moduleEtagere = defauts.bool(forKey: Cle.etagere)
        identifiantEcran = defauts.integer(forKey: Cle.ecran)
    }
}
