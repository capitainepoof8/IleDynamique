import AppKit
import Combine
import SwiftUI

enum TypeNiveau: Equatable {
    case volume
    case luminosite
}

/// Ce que l'île affiche de part et d'autre de l'encoche en mode compact.
enum ActiviteCompacte: Equatable {
    case aucune
    case musique
    case charge(pourcentage: Int)
    case niveau(TypeNiveau, Double)

    /// Largeur de chaque « aile » (gauche et droite) qui dépasse de l'encoche.
    var largeurAile: CGFloat {
        switch self {
        case .aucune: return 0
        case .musique: return 36
        case .charge: return 52
        case .niveau: return 72
        }
    }
}

enum Dimensions {
    static let largeurEtendue: CGFloat = 560
    static let espaceHaut: CGFloat = 6
    static let hauteurContenu: CGFloat = 104
    static let hauteurEtagere: CGFloat = 70
    static let margeBas: CGFloat = 14
    /// Petits coins concaves qui raccordent l'île au bord de l'écran.
    static let rayonOreille: CGFloat = 6
    static let rayonEtendu: CGFloat = 28
    /// Taille fixe du panneau transparent : assez grand pour l'état étendu + l'ombre.
    static let taillePanneau = CGSize(width: 720, height: 300)
    static let ressort = Animation.spring(response: 0.4, dampingFraction: 0.75)
}

@MainActor
final class IleViewModel: ObservableObject {
    @Published private(set) var estEtendue = false
    @Published private(set) var activiteTemporaire: ActiviteCompacte?
    @Published var geometrie = GeometrieEncoche.parDefaut
    /// Vrai pendant qu'un fichier est glissé au-dessus de l'île.
    @Published var depotEnCours = false {
        didSet { if !depotEnCours { evaluerSouris() } }
    }

    let preferences: Preferences
    let musique = ModuleMusique()
    let batterie = ModuleBatterie()
    let calendrier = ModuleCalendrier()
    let niveaux = ModuleVolumeLuminosite()
    let etagere = ModuleEtagere()

    /// Prévient le contrôleur de fenêtre : true = le panneau doit capter la souris.
    var interactionChangee: ((Bool) -> Void)?

    private var tacheRetraction: DispatchWorkItem?
    private var tacheFinActivite: DispatchWorkItem?
    private var abonnements = Set<AnyCancellable>()

    init(preferences: Preferences) {
        self.preferences = preferences

        // Relaie les changements des modules pour que la vue racine se redessine.
        let publieurs = [
            preferences.objectWillChange,
            musique.objectWillChange,
            batterie.objectWillChange,
            calendrier.objectWillChange,
            etagere.objectWillChange,
        ]
        for publieur in publieurs {
            publieur
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &abonnements)
        }
    }

    func demarrer() {
        batterie.surBranchement = { [weak self] pourcentage in
            guard let self, self.preferences.moduleBatterie else { return }
            self.afficherActivite(.charge(pourcentage: pourcentage), pendant: 3)
        }
        niveaux.surChangement = { [weak self] type, valeur in
            guard let self, self.preferences.moduleNiveaux else { return }
            self.afficherActivite(.niveau(type, valeur), pendant: 1.5)
        }

        musique.demarrer()
        batterie.demarrer()
        niveaux.demarrer()

        // Le calendrier ne demande l'autorisation que si le module est activé.
        preferences.$moduleCalendrier
            .removeDuplicates()
            .sink { [weak self] actif in
                if actif { self?.calendrier.demarrer() }
            }
            .store(in: &abonnements)
    }

    // MARK: - Activité compacte

    var activiteCompacte: ActiviteCompacte {
        if let activiteTemporaire { return activiteTemporaire }
        if preferences.moduleMusique && musique.estEnLecture { return .musique }
        return .aucune
    }

    private func afficherActivite(_ activite: ActiviteCompacte, pendant duree: TimeInterval) {
        activiteTemporaire = activite
        tacheFinActivite?.cancel()
        let tache = DispatchWorkItem { [weak self] in
            self?.activiteTemporaire = nil
        }
        tacheFinActivite = tache
        DispatchQueue.main.asyncAfter(deadline: .now() + duree, execute: tache)
    }

    // MARK: - Géométrie

    var hauteurEtendue: CGFloat {
        geometrie.tailleEncoche.height
            + Dimensions.espaceHaut
            + Dimensions.hauteurContenu
            + (preferences.moduleEtagere ? Dimensions.hauteurEtagere : 0)
            + Dimensions.margeBas
    }

    /// Taille totale de l'île (oreilles comprises).
    var tailleIle: CGSize {
        if estEtendue {
            return CGSize(width: Dimensions.largeurEtendue, height: hauteurEtendue)
        }
        let encoche = geometrie.tailleEncoche
        let largeur = encoche.width + 2 * Dimensions.rayonOreille + 2 * activiteCompacte.largeurAile
        return CGSize(width: largeur, height: encoche.height)
    }

    /// Rectangle de l'île en coordonnées écran, un peu élargi pour être facile à viser.
    private var zoneSensible: CGRect {
        let taille = tailleIle
        let ecran = geometrie.cadreEcran
        let rect = CGRect(
            x: ecran.midX - taille.width / 2,
            y: ecran.maxY - taille.height,
            width: taille.width,
            height: taille.height
        )
        return estEtendue ? rect.insetBy(dx: -10, dy: -10) : rect.insetBy(dx: -8, dy: -4)
    }

    // MARK: - Survol

    /// Appelé à chaque mouvement de souris (moniteurs d'événements, pas de minuteur).
    func evaluerSouris() {
        let dedans = zoneSensible.contains(NSEvent.mouseLocation)

        if dedans || depotEnCours {
            tacheRetraction?.cancel()
            tacheRetraction = nil
            if !estEtendue { etendre() }
        } else if estEtendue && tacheRetraction == nil {
            let tache = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.tacheRetraction = nil
                self.estEtendue = false
                self.evaluerSouris()
            }
            tacheRetraction = tache
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: tache)
        }

        interactionChangee?(dedans || depotEnCours)
    }

    private func etendre() {
        estEtendue = true
        // Rafraîchissements ponctuels à l'ouverture plutôt qu'en continu.
        if preferences.moduleCalendrier { calendrier.rafraichir() }
        if preferences.moduleMusique { musique.rafraichirSiActif() }
    }

    // MARK: - Glisser-déposer

    func deposer(_ fournisseurs: [NSItemProvider]) -> Bool {
        guard preferences.moduleEtagere else { return false }
        return etagere.ajouter(fournisseurs: fournisseurs)
    }
}
