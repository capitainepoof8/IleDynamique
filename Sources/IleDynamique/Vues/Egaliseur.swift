import SwiftUI

/// Petit égaliseur animé (affiché seulement pendant la lecture).
struct Egaliseur: View {
    @State private var anime = false
    private let durees: [Double] = [0.45, 0.62, 0.38, 0.54]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(durees.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.white)
                    .frame(width: 3, height: 14)
                    .scaleEffect(y: anime ? 1 : 0.3, anchor: .center)
                    .animation(
                        .easeInOut(duration: durees[index]).repeatForever(autoreverses: true),
                        value: anime
                    )
            }
        }
        .onAppear { anime = true }
    }
}
