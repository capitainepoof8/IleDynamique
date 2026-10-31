import SwiftUI

/// Vue racine affichée dans le panneau : l'île, collée en haut et centrée.
struct VueIle: View {
    @ObservedObject var vm: IleViewModel

    var body: some View {
        let taille = vm.tailleIle
        let forme = FormeIle(
            rayonOreille: Dimensions.rayonOreille,
            rayonBas: vm.estEtendue ? Dimensions.rayonEtendu : vm.geometrie.tailleEncoche.height * 0.32
        )

        ZStack(alignment: .top) {
            forme.fill(Color.black)

            Group {
                if vm.estEtendue {
                    VueEtendue(vm: vm)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                } else {
                    VueCompacte(vm: vm)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Dimensions.rayonOreille)
        }
        .frame(width: taille.width, height: taille.height, alignment: .top)
        .clipShape(forme)
        .contentShape(forme)
        .shadow(color: .black.opacity(vm.estEtendue ? 0.35 : 0), radius: 14, y: 6)
        .onDrop(
            of: vm.preferences.moduleEtagere ? [.fileURL] : [],
            isTargeted: $vm.depotEnCours,
            perform: vm.deposer
        )
        // L'île est toujours noire : contenu en apparence sombre, quel que soit le thème du système.
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Dimensions.ressort, value: vm.estEtendue)
        .animation(Dimensions.ressort, value: vm.activiteCompacte)
        .animation(Dimensions.ressort, value: vm.geometrie)
    }
}
