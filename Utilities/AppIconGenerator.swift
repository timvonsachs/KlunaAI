import SwiftUI
import UIKit

/// Generiert das Kluna App-Icon (1024x1024) und ermöglicht Export.
/// Spezifikation: K in SF Pro Rounded Bold, warmAccent (#E8825C), Creme-Hintergrund (#FFF8F0), weicher Glow.
struct AppIconGenerator: View {
    let size: CGFloat

    init(size: CGFloat = 1024) {
        self.size = size
    }

    var body: some View {
        ZStack {
            Color(hex: "FFF8F0")

            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "E8825C").opacity(0.3),
                    Color(hex: "E8825C").opacity(0.08),
                    Color.clear,
                ]),
                center: .center,
                startRadius: size * 0.08,
                endRadius: size * 0.4
            )

            Text("K")
                .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "E8825C"))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Export

extension AppIconGenerator {
    /// Rendert das App-Icon als UIImage (1024x1024) und speichert es in Documents.
    /// Gibt die URL der gespeicherten Datei zurück oder nil bei Fehler.
    @MainActor
    static func exportToDocuments() -> URL? {
        let size: CGFloat = 1024
        let view = AppIconGenerator(size: size)
            .frame(width: size, height: size)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        guard let image = renderer.uiImage,
              let data = image.pngData() else { return nil }

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let filename = "kluna_app_icon_1024.png"
        let url = docs.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AppIconGenerator_Previews: PreviewProvider {
    static var previews: some View {
        AppIconGenerator(size: 200)
            .previewLayout(.fixed(width: 200, height: 200))
    }
}
#endif
