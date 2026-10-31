import Foundation
import IOKit.ps

/// Niveau et état de charge, mis à jour par les notifications d'IOKit (pas de polling).
@MainActor
final class ModuleBatterie: ObservableObject {
    @Published private(set) var pourcentage = 100
    @Published private(set) var estBranche = false
    @Published private(set) var estEnCharge = false
    @Published private(set) var possedeBatterie = false

    /// Appelé quand on branche le chargeur.
    var surBranchement: ((Int) -> Void)?

    private var sourceBoucle: CFRunLoopSource?

    var symbole: String {
        if estEnCharge || estBranche { return "battery.100percent.bolt" }
        switch pourcentage {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    func demarrer() {
        guard sourceBoucle == nil else { return }
        lireEtat(premiereLecture: true)

        let contexte = Unmanaged.passUnretained(self).toOpaque()
        let rappel: IOPowerSourceCallbackType = { contexte in
            guard let contexte else { return }
            let module = Unmanaged<ModuleBatterie>.fromOpaque(contexte).takeUnretainedValue()
            MainActor.assumeIsolated { module.lireEtat(premiereLecture: false) }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(rappel, contexte)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        sourceBoucle = source
    }

    private func lireEtat(premiereLecture: Bool) {
        guard let infos = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(infos)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(infos, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            let actuelle = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = max(description[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
            let branche = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let ancienBranche = estBranche

            possedeBatterie = true
            pourcentage = Int((Double(actuelle) / Double(maximum) * 100).rounded())
            estBranche = branche
            estEnCharge = description[kIOPSIsChargingKey] as? Bool ?? false

            if !premiereLecture && branche && !ancienBranche {
                surBranchement?(pourcentage)
            }
            return
        }
        possedeBatterie = false
    }
}
