import SwiftUI

struct VueEnTete: View {
    @ObservedObject var batterie: ModuleBatterie
    let afficherBatterie: Bool

    var body: some View {
        HStack {
            // Ne se redessine qu'une fois par minute, et seulement quand l'île est ouverte.
            TimelineView(.everyMinute) { contexte in
                HStack(spacing: 6) {
                    Text(contexte.date, format: .dateTime.hour().minute())
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    Text(contexte.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if afficherBatterie && batterie.possedeBatterie {
                HStack(spacing: 5) {
                    Text("\(batterie.pourcentage) %")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                    Image(systemName: batterie.symbole)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(couleurBatterie, .white.opacity(0.6))
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private var couleurBatterie: Color {
        if batterie.estEnCharge || batterie.estBranche { return .green }
        return batterie.pourcentage <= 20 ? .red : .white
    }
}
