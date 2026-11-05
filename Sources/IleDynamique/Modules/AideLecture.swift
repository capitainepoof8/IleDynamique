import Foundation

/// Un état « À l'écoute » du système, tel qu'envoyé par l'aide de lecture.
struct EtatLectureSysteme: Decodable {
    var titre: String
    var artiste: String
    var album: String
    var duree: Double
    var position: Double
    var enLecture: Bool
    var bundle: String
    /// Absente si la pochette n'a pas changé depuis le message précédent (base64 sinon).
    var pochette: String?
    var pochetteRetiree: Bool?
}

/// Lance et pilote le processus d'aide (Sources/AideLecture/aide-lecture.m).
///
/// MediaRemote ne répond qu'aux processus Apple depuis macOS 15.4 : la bibliothèque est donc
/// chargée dans /usr/bin/perl, qui y a encore accès. Si Apple ferme cette voie, le module musique
/// retombe sur AppleScript (Musique et Spotify uniquement).
@MainActor
final class AideLecture {
    /// Script exécuté par perl : charge la bibliothèque et appelle son point d'entrée, sans retour.
    private static let chargeur = """
    use DynaLoader;
    my $b = DynaLoader::dl_load_file($ARGV[0], 0) or die DynaLoader::dl_error();
    my $s = DynaLoader::dl_find_symbol($b, "aide_lecture_demarrer") or die DynaLoader::dl_error();
    DynaLoader::dl_install_xsub("main::demarrer", $s);
    demarrer();
    """
    private static let maxRelancesRapides = 3

    private let surEtat: (EtatLectureSysteme) -> Void
    private let surIndisponible: () -> Void
    private var processus: Process?
    private var entree: FileHandle?
    private var relancesRapides = 0

    private(set) var estConnectee = false

    init(surEtat: @escaping (EtatLectureSysteme) -> Void, surIndisponible: @escaping () -> Void) {
        self.surEtat = surEtat
        self.surIndisponible = surIndisponible
    }

    func demarrer() {
        guard let bibliotheque = Bundle.main.path(forResource: "aide-lecture", ofType: "dylib") else {
            NSLog("IleDynamique – aide de lecture absente du bundle")
            surIndisponible()
            return
        }

        // Écrire vers une aide morte ne doit pas tuer l'app.
        signal(SIGPIPE, SIG_IGN)

        let processus = Process()
        processus.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        processus.arguments = ["-e", Self.chargeur, bibliotheque]
        let sortie = Pipe()
        let entree = Pipe()
        processus.standardOutput = sortie
        processus.standardInput = entree

        let lancement = Date()
        processus.terminationHandler = { [weak self] _ in
            sortie.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { self?.termine(apres: Date().timeIntervalSince(lancement)) }
        }

        var tampon = Data()
        sortie.fileHandleForReading.readabilityHandler = { [weak self] poignee in
            tampon.append(poignee.availableData)
            while let fin = tampon.firstIndex(of: 0x0A) {
                let ligne = tampon[tampon.startIndex..<fin]
                tampon = Data(tampon[tampon.index(after: fin)...])
                guard let etat = try? JSONDecoder().decode(EtatLectureSysteme.self, from: ligne) else { continue }
                DispatchQueue.main.async {
                    self?.estConnectee = true
                    self?.relancesRapides = 0
                    self?.surEtat(etat)
                }
            }
        }

        do {
            try processus.run()
            self.processus = processus
            self.entree = entree.fileHandleForWriting
        } catch {
            NSLog("IleDynamique – lancement de l'aide impossible : %@", String(describing: error))
            surIndisponible()
        }
    }

    func envoyer(_ commande: String) {
        guard let donnees = "\(commande)\n".data(using: .utf8) else { return }
        try? entree?.write(contentsOf: donnees)
    }

    private func termine(apres duree: TimeInterval) {
        processus = nil
        entree = nil
        estConnectee = false
        surIndisponible()

        // Une aide qui meurt aussitôt n'a aucune chance de guérir : on abandonne après quelques essais.
        relancesRapides = duree < 10 ? relancesRapides + 1 : 0
        guard relancesRapides <= Self.maxRelancesRapides else {
            NSLog("IleDynamique – aide de lecture abandonnée, repli sur AppleScript")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.demarrer()
        }
    }
}
