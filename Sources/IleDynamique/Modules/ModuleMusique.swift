import AppKit

enum SourceMusicale: String, CaseIterable {
    case musique
    case spotify

    var identifiantBundle: String {
        switch self {
        case .musique: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        }
    }

    /// Notification distribuée publiée par l'app à chaque changement de lecture.
    var notification: Notification.Name {
        switch self {
        case .musique: return Notification.Name("com.apple.Music.playerInfo")
        case .spotify: return Notification.Name("com.spotify.client.PlaybackStateChanged")
        }
    }

    /// On ne scripte jamais une app fermée : AppleScript la relancerait.
    var estLancee: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: identifiantBundle).isEmpty
    }

    var scriptInfos: String {
        switch self {
        case .musique:
            return """
            tell application id "com.apple.Music"
                try
                    set etat to player state as text
                    if etat is "stopped" then return {"stopped"}
                    set morceau to current track
                    return {etat, name of morceau, artist of morceau, album of morceau, (duration of morceau) as real, player position as real, ""}
                on error
                    return {"stopped"}
                end try
            end tell
            """
        case .spotify:
            return """
            tell application id "com.spotify.client"
                try
                    set etat to player state as text
                    if etat is "stopped" then return {"stopped"}
                    set morceau to current track
                    return {etat, name of morceau, artist of morceau, album of morceau, ((duration of morceau) / 1000) as real, player position as real, artwork url of morceau}
                on error
                    return {"stopped"}
                end try
            end tell
            """
        }
    }
}

private struct InfosLecture {
    var etat: String
    var titre = ""
    var artiste = ""
    var album = ""
    var duree: Double = 0
    var position: Double = 0
    var urlPochette = ""
}

/// Lecture en cours dans Musique ou Spotify, via notifications distribuées + AppleScript (aucune API privée).
@MainActor
final class ModuleMusique: ObservableObject {
    @Published private(set) var titre = ""
    @Published private(set) var artiste = ""
    @Published private(set) var album = ""
    @Published private(set) var pochette: NSImage?
    @Published private(set) var estEnLecture = false
    @Published private(set) var duree: Double = 0
    @Published private(set) var source: SourceMusicale?
    /// Position connue à `dateDeReference` : la vue extrapole sans interroger l'app chaque seconde.
    private(set) var positionDeReference: Double = 0
    private(set) var dateDeReference = Date()

    /// NSAppleScript bloque : on l'exécute sur une file série dédiée.
    private let fileAppleScript = DispatchQueue(label: "fr.iledynamique.applescript", qos: .userInitiated)
    private var clePochette = ""

    var aUnMorceau: Bool { !titre.isEmpty }

    func position(a date: Date) -> Double {
        guard estEnLecture else { return positionDeReference }
        return min(duree, positionDeReference + date.timeIntervalSince(dateDeReference))
    }

    // MARK: - Démarrage

    func demarrer() {
        let centre = DistributedNotificationCenter.default()
        for source in SourceMusicale.allCases {
            centre.addObserver(forName: source.notification, object: nil, queue: .main) { [weak self] notification in
                let etat = notification.userInfo?["Player State"] as? String
                MainActor.assumeIsolated { self?.notificationRecue(de: source, etat: etat) }
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let identifiant = application?.bundleIdentifier
            MainActor.assumeIsolated {
                guard let self, self.source?.identifiantBundle == identifiant else { return }
                self.vider()
            }
        }

        // État initial si une lecture est déjà en cours au lancement.
        for source in SourceMusicale.allCases where source.estLancee {
            rafraichir(source)
        }
    }

    func rafraichirSiActif() {
        if let source { rafraichir(source) }
    }

    // MARK: - Commandes

    func lectureOuPause() { envoyer("playpause") }
    func suivant() { envoyer("next track") }
    func precedent() { envoyer("previous track") }

    private func envoyer(_ commande: String) {
        let cible = source ?? SourceMusicale.allCases.first(where: { $0.estLancee }) ?? .musique
        let script = "tell application id \"\(cible.identifiantBundle)\" to \(commande)"
        fileAppleScript.async {
            _ = Self.executer(script)
        }
        // L'app enverra sa notification « playerInfo » : pas besoin de rafraîchir nous-mêmes.
    }

    // MARK: - Mise à jour

    private func notificationRecue(de source: SourceMusicale, etat: String?) {
        if etat == "Stopped" {
            if self.source == source { vider() }
            return
        }
        rafraichir(source)
    }

    private func rafraichir(_ source: SourceMusicale) {
        guard source.estLancee else { return }
        let script = source.scriptInfos
        fileAppleScript.async { [weak self] in
            let infos = Self.lireInfos(Self.executer(script))
            DispatchQueue.main.async {
                self?.appliquer(infos, de: source)
            }
        }
    }

    private func appliquer(_ infos: InfosLecture, de source: SourceMusicale) {
        if infos.etat == "stopped" {
            if self.source == source { vider() }
            return
        }
        // Une app en pause ne vole pas la place de celle qui joue.
        if infos.etat != "playing", let actuelle = self.source, actuelle != source, estEnLecture {
            return
        }

        self.source = source
        titre = infos.titre
        artiste = infos.artiste
        album = infos.album
        duree = infos.duree
        positionDeReference = infos.position
        dateDeReference = Date()
        estEnLecture = infos.etat == "playing"

        let cle = "\(source.rawValue)|\(infos.titre)|\(infos.artiste)|\(infos.album)"
        if cle != clePochette {
            clePochette = cle
            pochette = nil
            chargerPochette(de: source, url: infos.urlPochette, cle: cle)
        }
    }

    private func vider() {
        source = nil
        titre = ""
        artiste = ""
        album = ""
        duree = 0
        positionDeReference = 0
        estEnLecture = false
        pochette = nil
        clePochette = ""
    }

    // MARK: - Pochette

    private func chargerPochette(de source: SourceMusicale, url: String, cle: String) {
        switch source {
        case .musique:
            let script = """
            tell application id "com.apple.Music"
                try
                    return raw data of artwork 1 of current track
                on error
                    return missing value
                end try
            end tell
            """
            fileAppleScript.async { [weak self] in
                let donnees = Self.executer(script)?.data
                let image = donnees.flatMap { NSImage(data: $0) }
                DispatchQueue.main.async {
                    self?.definirPochette(image, cle: cle)
                }
            }
        case .spotify:
            guard let adresse = URL(string: url) else { return }
            URLSession.shared.dataTask(with: adresse) { [weak self] donnees, _, _ in
                let image = donnees.flatMap { NSImage(data: $0) }
                DispatchQueue.main.async {
                    self?.definirPochette(image, cle: cle)
                }
            }.resume()
        }
    }

    private func definirPochette(_ image: NSImage?, cle: String) {
        // Ignore une réponse arrivée après un changement de morceau.
        guard cle == clePochette else { return }
        pochette = image
    }

    // MARK: - AppleScript

    nonisolated private static func executer(_ source: String) -> NSAppleEventDescriptor? {
        var erreur: NSDictionary?
        let resultat = NSAppleScript(source: source)?.executeAndReturnError(&erreur)
        if let erreur {
            NSLog("IleDynamique – AppleScript : %@", erreur)
        }
        return resultat
    }

    nonisolated private static func lireInfos(_ descripteur: NSAppleEventDescriptor?) -> InfosLecture {
        guard let descripteur, descripteur.numberOfItems >= 7 else {
            return InfosLecture(etat: "stopped")
        }
        func texte(_ index: Int) -> String { descripteur.atIndex(index)?.stringValue ?? "" }
        func nombre(_ index: Int) -> Double { descripteur.atIndex(index)?.doubleValue ?? 0 }

        return InfosLecture(
            etat: texte(1),
            titre: texte(2),
            artiste: texte(3),
            album: texte(4),
            duree: nombre(5),
            position: nombre(6),
            urlPochette: texte(7)
        )
    }
}
