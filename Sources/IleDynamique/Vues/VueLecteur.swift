import SwiftUI

struct VueLecteur: View {
    @ObservedObject var musique: ModuleMusique

    var body: some View {
        HStack(spacing: 12) {
            pochette

            VStack(alignment: .leading, spacing: 5) {
                Text(musique.aUnMorceau ? musique.titre : "Aucune lecture")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(musique.aUnMorceau ? musique.sousTitre : "Lancez une musique ou une vidéo")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Pas de durée pour un direct : la barre n'aurait aucun sens.
                if musique.aUnMorceau && musique.duree > 0 {
                    BarreProgression(musique: musique)
                }

                HStack(spacing: 24) {
                    BoutonCommande(symbole: "backward.fill", taille: 14, action: musique.precedent)
                    BoutonCommande(
                        symbole: musique.estEnLecture ? "pause.fill" : "play.fill",
                        taille: 20,
                        action: musique.lectureOuPause
                    )
                    BoutonCommande(symbole: "forward.fill", taille: 14, action: musique.suivant)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var pochette: some View {
        Group {
            if let image = musique.imageAffichee {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BarreProgression: View {
    @ObservedObject var musique: ModuleMusique

    var body: some View {
        // Une mise à jour par seconde, en pause quand la musique est arrêtée.
        TimelineView(.animation(minimumInterval: 1, paused: !musique.estEnLecture)) { contexte in
            let position = musique.position(a: contexte.date)
            let fraction = musique.duree > 0 ? min(1, position / musique.duree) : 0

            VStack(spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2))
                        Capsule().fill(Color.white).frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(formater(position))
                    Spacer()
                    Text("-" + formater(max(0, musique.duree - position)))
                }
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }

    private func formater(_ secondes: Double) -> String {
        let total = Int(secondes)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct BoutonCommande: View {
    let symbole: String
    let taille: CGFloat
    let action: () -> Void
    @State private var survole = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbole)
                .font(.system(size: taille, weight: .semibold))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
                .opacity(survole ? 1 : 0.85)
                .scaleEffect(survole ? 1.1 : 1)
        }
        .buttonStyle(.plain)
        .onHover { survole = $0 }
        .animation(.easeOut(duration: 0.15), value: survole)
    }
}
