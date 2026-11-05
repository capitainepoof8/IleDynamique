import SwiftUI

/// État compact : rien, ou une activité « live » répartie à gauche et à droite de l'encoche.
struct VueCompacte: View {
    @ObservedObject var vm: IleViewModel

    var body: some View {
        let activite = vm.activiteCompacte
        let aile = activite.largeurAile

        HStack(spacing: 0) {
            aileGauche(activite)
                .frame(width: aile)
            Spacer(minLength: 0)
            aileDroite(activite)
                .frame(width: aile)
        }
        .frame(
            width: vm.tailleIle.width - 2 * Dimensions.rayonOreille,
            height: vm.geometrie.tailleEncoche.height
        )
    }

    @ViewBuilder
    private func aileGauche(_ activite: ActiviteCompacte) -> some View {
        switch activite {
        case .aucune:
            EmptyView()
        case .musique:
            Group {
                if let pochette = vm.musique.imageAffichee {
                    Image(nsImage: pochette)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.15))
                }
            }
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        case .charge:
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        case let .niveau(type, valeur):
            Image(systemName: symbole(type, valeur))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func aileDroite(_ activite: ActiviteCompacte) -> some View {
        switch activite {
        case .aucune:
            EmptyView()
        case .musique:
            Egaliseur()
        case let .charge(pourcentage):
            Text("\(pourcentage) %")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.green)
        case let .niveau(_, valeur):
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule().fill(Color.white).frame(width: geo.size.width * valeur)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 10)
        }
    }

    private func symbole(_ type: TypeNiveau, _ valeur: Double) -> String {
        switch type {
        case .luminosite:
            return valeur < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .volume:
            if valeur == 0 { return "speaker.slash.fill" }
            return valeur < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill"
        }
    }
}
