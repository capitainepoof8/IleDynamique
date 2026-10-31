import AppKit
import UniformTypeIdentifiers

/// Fichiers déposés temporairement sur l'île (références en mémoire, vidées à la fermeture).
@MainActor
final class ModuleEtagere: ObservableObject {
    struct Element: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let icone: NSImage
    }

    @Published private(set) var elements: [Element] = []

    func ajouter(fournisseurs: [NSItemProvider]) -> Bool {
        var accepte = false
        for fournisseur in fournisseurs where fournisseur.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepte = true
            _ = fournisseur.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    self?.ajouter(url)
                }
            }
        }
        return accepte
    }

    func ajouter(_ url: URL) {
        guard !elements.contains(where: { $0.url == url }) else { return }
        elements.append(Element(url: url, icone: NSWorkspace.shared.icon(forFile: url.path)))
    }

    func retirer(_ element: Element) {
        elements.removeAll { $0.id == element.id }
    }

    func vider() {
        elements.removeAll()
    }
}
