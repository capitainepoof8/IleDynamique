import AppKit

/// Décrit l'écran cible et la taille de l'encoche (ou de la pilule de remplacement).
struct GeometrieEncoche: Equatable {
    var cadreEcran: CGRect
    var tailleEncoche: CGSize
    var possedeEncoche: Bool

    static let parDefaut = GeometrieEncoche(
        cadreEcran: .zero,
        tailleEncoche: CGSize(width: 180, height: 30),
        possedeEncoche: false
    )

    static func pour(ecran: NSScreen) -> GeometrieEncoche {
        let cadre = ecran.frame
        let hauteurEncoche = ecran.safeAreaInsets.top

        if hauteurEncoche > 0,
           let gauche = ecran.auxiliaryTopLeftArea,
           let droite = ecran.auxiliaryTopRightArea {
            // L'encoche occupe l'espace laissé libre entre les deux zones auxiliaires.
            let largeur = cadre.width - gauche.width - droite.width
            return GeometrieEncoche(
                cadreEcran: cadre,
                tailleEncoche: CGSize(width: largeur, height: hauteurEncoche),
                possedeEncoche: true
            )
        }

        // Mac sans encoche : pilule légèrement plus haute que la barre des menus.
        let hauteurBarre = max(cadre.maxY - ecran.visibleFrame.maxY, NSStatusBar.system.thickness)
        return GeometrieEncoche(
            cadreEcran: cadre,
            tailleEncoche: CGSize(width: 180, height: hauteurBarre + 6),
            possedeEncoche: false
        )
    }

    /// Écran choisi dans les préférences ; sinon celui qui a une encoche ; sinon l'écran principal.
    static func ecranCible(identifiant: Int) -> NSScreen? {
        let ecrans = NSScreen.screens
        if identifiant != 0, let ecran = ecrans.first(where: { $0.identifiant == identifiant }) {
            return ecran
        }
        return ecrans.first(where: { $0.safeAreaInsets.top > 0 }) ?? ecrans.first
    }
}

extension NSScreen {
    /// Identifiant CoreGraphics de l'écran (stable tant que l'écran reste branché).
    var identifiant: Int {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue ?? 0
    }
}
