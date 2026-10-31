import SwiftUI

/// État étendu : en-tête (heure, batterie), lecteur, calendrier et étagère.
struct VueEtendue: View {
    @ObservedObject var vm: IleViewModel

    var body: some View {
        let preferences = vm.preferences

        VStack(spacing: 0) {
            // Rangée à hauteur de l'encoche : le centre est caché par l'encoche physique.
            VueEnTete(batterie: vm.batterie, afficherBatterie: preferences.moduleBatterie)
                .frame(height: vm.geometrie.tailleEncoche.height)

            HStack(spacing: 14) {
                if preferences.moduleMusique {
                    VueLecteur(musique: vm.musique)
                }
                if preferences.moduleMusique && preferences.moduleCalendrier {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }
                if preferences.moduleCalendrier {
                    VueCalendrier(calendrier: vm.calendrier)
                        .frame(width: preferences.moduleMusique ? 170 : nil)
                }
                if !preferences.moduleMusique && !preferences.moduleCalendrier {
                    VueGrandeHorloge()
                }
            }
            .frame(height: Dimensions.hauteurContenu)
            .padding(.top, Dimensions.espaceHaut)

            if preferences.moduleEtagere {
                VueEtagere(etagere: vm.etagere, ciblee: vm.depotEnCours)
                    .padding(.top, 10)
                    .frame(height: Dimensions.hauteurEtagere)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, Dimensions.margeBas)
        .foregroundStyle(.white)
        .frame(
            width: Dimensions.largeurEtendue - 2 * Dimensions.rayonOreille,
            height: vm.hauteurEtendue,
            alignment: .top
        )
    }
}

/// Affichée quand ni le lecteur ni le calendrier ne sont activés.
private struct VueGrandeHorloge: View {
    var body: some View {
        TimelineView(.everyMinute) { contexte in
            VStack(spacing: 2) {
                Text(contexte.date, format: .dateTime.hour().minute())
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                Text(contexte.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
