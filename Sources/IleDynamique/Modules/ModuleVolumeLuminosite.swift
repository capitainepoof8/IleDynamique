import AppKit
import CoreAudio

/// Détecte les changements de volume (écouteurs CoreAudio) et de luminosité (touches dédiées).
@MainActor
final class ModuleVolumeLuminosite {
    var surChangement: ((TypeNiveau, Double) -> Void)?

    private var appareil = AudioObjectID(kAudioObjectUnknown)
    private var adresseVolume = AudioObjectPropertyAddress()
    private var adresseMuet = AudioObjectPropertyAddress()
    private var ecouteurVolume: AudioObjectPropertyListenerBlock?
    private var ecouteurMuet: AudioObjectPropertyListenerBlock?
    private var moniteurTouches: Any?

    func demarrer() {
        // Suit le changement de sortie audio par défaut (casque, AirPods…).
        var adresse = Self.adresse(kAudioHardwarePropertyDefaultOutputDevice, portee: kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &adresse, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.suivreSortieParDefaut() }
        }
        suivreSortieParDefaut()

        // Touches de luminosité (nécessite l'autorisation Accessibilité).
        moniteurTouches = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] evenement in
            MainActor.assumeIsolated { self?.toucheSysteme(evenement) }
        }
    }

    // MARK: - Volume

    private func suivreSortieParDefaut() {
        retirerEcouteurs()

        var identifiant = AudioObjectID(kAudioObjectUnknown)
        var taille = UInt32(MemoryLayout<AudioObjectID>.size)
        var adresse = Self.adresse(kAudioHardwarePropertyDefaultOutputDevice, portee: kAudioObjectPropertyScopeGlobal)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &adresse, 0, nil, &taille, &identifiant) == noErr,
              identifiant != kAudioObjectUnknown
        else { return }
        appareil = identifiant

        // Volume principal si disponible, sinon celui du canal 1.
        adresseVolume = Self.adresse(kAudioDevicePropertyVolumeScalar, portee: kAudioDevicePropertyScopeOutput)
        if !AudioObjectHasProperty(identifiant, &adresseVolume) { adresseVolume.mElement = 1 }
        if AudioObjectHasProperty(identifiant, &adresseVolume) {
            let bloc: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.volumeModifie() }
            }
            AudioObjectAddPropertyListenerBlock(identifiant, &adresseVolume, .main, bloc)
            ecouteurVolume = bloc
        }

        adresseMuet = Self.adresse(kAudioDevicePropertyMute, portee: kAudioDevicePropertyScopeOutput)
        if AudioObjectHasProperty(identifiant, &adresseMuet) {
            let bloc: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.volumeModifie() }
            }
            AudioObjectAddPropertyListenerBlock(identifiant, &adresseMuet, .main, bloc)
            ecouteurMuet = bloc
        }
    }

    private func retirerEcouteurs() {
        if let ecouteurVolume {
            AudioObjectRemovePropertyListenerBlock(appareil, &adresseVolume, .main, ecouteurVolume)
        }
        if let ecouteurMuet {
            AudioObjectRemovePropertyListenerBlock(appareil, &adresseMuet, .main, ecouteurMuet)
        }
        ecouteurVolume = nil
        ecouteurMuet = nil
    }

    private func volumeModifie() {
        var volume: Float32 = 0
        var taille = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(appareil, &adresseVolume, 0, nil, &taille, &volume) == noErr else { return }

        var muet: UInt32 = 0
        var tailleMuet = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectHasProperty(appareil, &adresseMuet) {
            AudioObjectGetPropertyData(appareil, &adresseMuet, 0, nil, &tailleMuet, &muet)
        }
        surChangement?(.volume, muet != 0 ? 0 : Double(volume))
    }

    private static func adresse(
        _ selecteur: AudioObjectPropertySelector,
        portee: AudioObjectPropertyScope
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selecteur, mScope: portee, mElement: kAudioObjectPropertyElementMain)
    }

    // MARK: - Luminosité

    /// Il n'existe pas d'API publique pour lire la luminosité de l'écran intégré sur Apple Silicon.
    /// On charge DisplayServices dynamiquement : si la fonction disparaît, le module se désactive simplement.
    private typealias FonctionLireLuminosite = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private static let lireLuminosite: FonctionLireLuminosite? = {
        let chemin = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let bibliotheque = dlopen(chemin, RTLD_LAZY),
              let symbole = dlsym(bibliotheque, "DisplayServicesGetBrightness")
        else { return nil }
        return unsafeBitCast(symbole, to: FonctionLireLuminosite.self)
    }()

    private func toucheSysteme(_ evenement: NSEvent) {
        // Sous-type 8 = touches spéciales (son, luminosité, lecture…).
        guard evenement.subtype.rawValue == 8 else { return }
        let code = (evenement.data1 & 0xFFFF_0000) >> 16
        let enfoncee = ((evenement.data1 & 0xFF00) >> 8) == 0xA
        // NX_KEYTYPE_BRIGHTNESS_UP = 2, NX_KEYTYPE_BRIGHTNESS_DOWN = 3
        guard enfoncee, code == 2 || code == 3 else { return }

        // Laisse le système appliquer la nouvelle luminosité avant de la lire.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.luminositeModifiee()
        }
    }

    private func luminositeModifiee() {
        guard let lire = Self.lireLuminosite else { return }
        let ecranIntegre = NSScreen.screens
            .map { CGDirectDisplayID($0.identifiant) }
            .first(where: { CGDisplayIsBuiltin($0) != 0 }) ?? CGMainDisplayID()

        var valeur: Float = 0
        guard lire(ecranIntegre, &valeur) == 0 else { return }
        surChangement?(.luminosite, Double(valeur))
    }
}
