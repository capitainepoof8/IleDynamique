import AppKit
import SwiftUI

struct VuePreferences: View {
    @ObservedObject var preferences: Preferences
    @State private var lancementAuDemarrage = LancementAuDemarrage.estActif
    @State private var messageErreur: String?
    @State private var ecrans: [NSScreen] = NSScreen.screens

    var body: some View {
        Form {
            Section("Modules") {
                Toggle("Lecteur multimédia (Musique, Spotify)", isOn: $preferences.moduleMusique)
                Toggle("Batterie et charge", isOn: $preferences.moduleBatterie)
                Toggle("Volume et luminosité", isOn: $preferences.moduleNiveaux)
                Toggle("Prochain événement du calendrier", isOn: $preferences.moduleCalendrier)
                Toggle("Étagère de fichiers", isOn: $preferences.moduleEtagere)
            }

            Section("Général") {
                Toggle("Lancer au démarrage", isOn: Binding(
                    get: { lancementAuDemarrage },
                    set: { changerLancementAuDemarrage($0) }
                ))
                Picker("Écran d'affichage", selection: $preferences.identifiantEcran) {
                    Text("Automatique (encoche en priorité)").tag(0)
                    ForEach(ecrans, id: \.identifiant) { ecran in
                        Text(ecran.localizedName).tag(ecran.identifiant)
                    }
                }
                if let messageErreur {
                    Text(messageErreur)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Autorisations") {
                BoutonReglages(titre: "Calendrier", ancre: "Privacy_Calendars")
                BoutonReglages(titre: "Automatisation (Musique, Spotify)", ancre: "Privacy_Automation")
                BoutonReglages(titre: "Accessibilité (touches de luminosité)", ancre: "Privacy_Accessibility")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            ecrans = NSScreen.screens
        }
    }

    private func changerLancementAuDemarrage(_ actif: Bool) {
        do {
            try LancementAuDemarrage.definir(actif)
            messageErreur = nil
        } catch {
            messageErreur = "Impossible de modifier le lancement au démarrage : \(error.localizedDescription)"
        }
        lancementAuDemarrage = LancementAuDemarrage.estActif
    }
}

private struct BoutonReglages: View {
    let titre: String
    let ancre: String

    var body: some View {
        LabeledContent(titre) {
            Button("Ouvrir…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(ancre)") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
