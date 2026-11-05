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

/// Lecture en cours dans n'importe quelle app, via l'« À l'écoute » du système (voir `AideLecture`).
/// Repli : Musique et Spotify via notifications distribuées + AppleScript si l'aide ne répond pas.
@MainActor
final class ModuleMusique: ObservableObject {
    @Published private(set) var titre = ""
    @Published private(set) var artiste = ""
    @Published private(set) var album = ""
    @Published private(set) var pochette: NSImage?
    @Published private(set) var estEnLecture = false
    @Published private(set) var duree: Double = 0
    @Published private(set) var source: SourceMusicale?
    /// App à l'origine de la lecture système (navigateur, lecteur vidéo…), si elle est connue.
    @Published private(set) var nomApp = ""
    @Published private(set) var iconeApp: NSImage?
    /// Position connue à `dateDeReference` : la vue extrapole sans interroger l'app chaque seconde.
    private(set) var positionDeReference: Double = 0
    private(set) var dateDeReference = Date()

    /// NSAppleScript bloque : on l'exécute sur une file série dédiée.
    private let fileAppleScript = DispatchQueue(label: "fr.iledynamique.applescript", qos: .userInitiated)
    private var clePochette = ""
    private var bundleApp = ""
    /// Vrai tant que l'« À l'écoute » du système fournit un morceau : il a priorité sur AppleScript.
    private var lectureSystemeActive = false
    private var pochetteSysteme: NSImage?
    private var finLectureSysteme: DispatchWorkItem?
    private lazy var aide = AideLecture(
        surEtat: { [weak self] etat in self?.appliquer(etat) },
        surIndisponible: { [weak self] in self?.aideIndisponible() }
    )

    var aUnMorceau: Bool { !titre.isEmpty }

    /// Les vidéos n'ont souvent pas d'artiste : on affiche alors l'app qui les joue.
    var sousTitre: String { artiste.isEmpty ? nomApp : artiste }
    var imageAffichee: NSImage? { pochette ?? iconeApp }

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

        // L'aide envoie aussitôt l'état initial ; AppleScript n'est interrogé que si elle n'a rien.
        aide.demarrer()
    }

    func rafraichirSiActif() {
        if aide.estConnectee { aide.envoyer("refresh") }
        if let source { rafraichir(source) }
    }

    // MARK: - Commandes

    func lectureOuPause() { envoyer("playpause", aide: "playpause") }
    func suivant() { envoyer("next track", aide: "next") }
    func precedent() { envoyer("previous track", aide: "prev") }

    private func envoyer(_ commande: String, aide commandeAide: String) {
        if lectureSystemeActive {
            aide.envoyer(commandeAide)
            return
        }
        let cible = source ?? SourceMusicale.allCases.first(where: { $0.estLancee }) ?? .musique
        let script = "tell application id \"\(cible.identifiantBundle)\" to \(commande)"
        fileAppleScript.async {
            _ = Self.executer(script)
        }
        // L'app enverra sa notification « playerInfo » : pas besoin de rafraîchir nous-mêmes.
    }

    // MARK: - Mise à jour

    private func appliquer(_ etat: EtatLectureSysteme) {
        // L'aide n'envoie chaque pochette qu'une fois, même si elle arrive pendant un titre vide.
        if let base64 = etat.pochette {
            pochetteSysteme = Data(base64Encoded: base64).flatMap { NSImage(data: $0) }
        } else if etat.pochetteRetiree == true {
            pochetteSysteme = nil
        }

        guard !etat.titre.isEmpty else {
            planifierFinLectureSysteme()
            return
        }

        finLectureSysteme?.cancel()
        finLectureSysteme = nil
        lectureSystemeActive = true
        source = nil
        clePochette = ""
        titre = etat.titre
        artiste = etat.artiste
        album = etat.album
        duree = etat.duree
        positionDeReference = etat.position
        dateDeReference = Date()
        estEnLecture = etat.enLecture
        definirApp(bundle: etat.bundle)
        pochette = pochetteSysteme
    }

    /// Au changement de morceau, le système publie brièvement un titre vide : on attend
    /// avant de conclure que la lecture est finie, sinon l'île clignote.
    private func planifierFinLectureSysteme() {
        guard finLectureSysteme == nil else { return }
        let fin = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.terminerLectureSysteme() }
        }
        finLectureSysteme = fin
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: fin)
    }

    private func terminerLectureSysteme() {
        finLectureSysteme?.cancel()
        finLectureSysteme = nil
        if lectureSystemeActive { vider() }
        lectureSystemeActive = false
        interrogerAppsScriptables()
    }

    private func definirApp(bundle: String) {
        guard bundle != bundleApp else { return }
        bundleApp = bundle
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else {
            nomApp = ""
            iconeApp = nil
            return
        }
        nomApp = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        iconeApp = NSWorkspace.shared.icon(forFile: url.path)
    }

    private func aideIndisponible() {
        pochetteSysteme = nil
        terminerLectureSysteme()
    }

    private func interrogerAppsScriptables() {
        for source in SourceMusicale.allCases where source.estLancee {
            rafraichir(source)
        }
    }

    private func notificationRecue(de source: SourceMusicale, etat: String?) {
        guard !lectureSystemeActive else { return }
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
        guard !lectureSystemeActive else { return }
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
        bundleApp = ""
        nomApp = ""
        iconeApp = nil
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
