import AppKit
import SwiftUI

struct VueCalendrier: View {
    @ObservedObject var calendrier: ModuleCalendrier

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Prochain événement", systemImage: "calendar")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            switch calendrier.autorisation {
            case .enAttente:
                Text("Autorisation en attente…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            case .refuse:
                Text("Accès au calendrier refusé")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("Ouvrir les réglages") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            case .autorise:
                if let evenement = calendrier.prochain {
                    VueEvenement(evenement: evenement)
                } else {
                    Text("Rien de prévu dans les 7 prochains jours")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

private struct VueEvenement: View {
    let evenement: EvenementResume

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: evenement.couleur))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(evenement.titre)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                Text(horaire)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TimelineView(.everyMinute) { contexte in
                    Text(echeance(a: contexte.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(nsColor: evenement.couleur))
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var horaire: String {
        if evenement.journeeEntiere {
            return evenement.debut.formatted(.dateTime.weekday(.wide).day().month()) + " · toute la journée"
        }
        let debut = evenement.debut.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        let fin = evenement.fin.formatted(date: .omitted, time: .shortened)
        return "\(debut) – \(fin)"
    }

    private func echeance(a maintenant: Date) -> String {
        if evenement.debut <= maintenant { return "En cours" }
        let formateur = RelativeDateTimeFormatter()
        formateur.unitsStyle = .full
        return formateur.localizedString(for: evenement.debut, relativeTo: maintenant)
    }
}
