import SwiftUI

/// Forme de l'île : bord supérieur collé à l'écran avec deux petits raccords concaves,
/// coins inférieurs arrondis « continus » (courbes de Bézier plus douces qu'un arc de cercle).
struct FormeIle: Shape {
    var rayonOreille: CGFloat
    var rayonBas: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(rayonOreille, rayonBas) }
        set {
            rayonOreille = newValue.first
            rayonBas = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let o = rayonOreille
        let r = min(rayonBas, (rect.width - 2 * o) / 2, rect.height - o)
        var chemin = Path()

        chemin.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Raccord concave en haut à gauche
        chemin.addQuadCurve(
            to: CGPoint(x: rect.minX + o, y: rect.minY + o),
            control: CGPoint(x: rect.minX + o, y: rect.minY)
        )
        chemin.addLine(to: CGPoint(x: rect.minX + o, y: rect.maxY - r))
        // Coin bas gauche
        chemin.addCurve(
            to: CGPoint(x: rect.minX + o + r, y: rect.maxY),
            control1: CGPoint(x: rect.minX + o, y: rect.maxY - r * 0.35),
            control2: CGPoint(x: rect.minX + o + r * 0.35, y: rect.maxY)
        )
        chemin.addLine(to: CGPoint(x: rect.maxX - o - r, y: rect.maxY))
        // Coin bas droit
        chemin.addCurve(
            to: CGPoint(x: rect.maxX - o, y: rect.maxY - r),
            control1: CGPoint(x: rect.maxX - o - r * 0.35, y: rect.maxY),
            control2: CGPoint(x: rect.maxX - o, y: rect.maxY - r * 0.35)
        )
        chemin.addLine(to: CGPoint(x: rect.maxX - o, y: rect.minY + o))
        // Raccord concave en haut à droite
        chemin.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - o, y: rect.minY)
        )
        chemin.closeSubpath()
        return chemin
    }
}
