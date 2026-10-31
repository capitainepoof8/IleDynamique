import AppKit
import SwiftUI

/// Zone où l'on dépose des fichiers, puis d'où on les ressort par glisser-déposer.
struct VueEtagere: View {
    @ObservedObject var etagere: ModuleEtagere
    let ciblee: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(ciblee ? 0.1 : 0.04))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    ciblee ? Color.accentColor : Color.white.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )

            if etagere.elements.isEmpty {
                Label("Glissez des fichiers ici", systemImage: "tray.and.arrow.down")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(etagere.elements) { element in
                                VueElementEtagere(element: element, etagere: etagere)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    Button(action: etagere.vider) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Vider l'étagère")
                    .padding(.trailing, 10)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: ciblee)
    }
}

private struct VueElementEtagere: View {
    let element: ModuleEtagere.Element
    let etagere: ModuleEtagere

    var body: some View {
        VStack(spacing: 2) {
            Image(nsImage: element.icone)
                .resizable()
                .frame(width: 32, height: 32)
            Text(element.url.lastPathComponent)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 60)
        .contentShape(Rectangle())
        .onDrag {
            NSItemProvider(contentsOf: element.url) ?? NSItemProvider()
        }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(element.url)
        }
        .contextMenu {
            Button("Ouvrir") { NSWorkspace.shared.open(element.url) }
            Button("Afficher dans le Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([element.url])
            }
            Divider()
            Button("Retirer de l'étagère") { etagere.retirer(element) }
        }
        .help(element.url.path)
    }
}
