import SwiftUI
import BriefLogik

// Bausteine, die App und Widgets gemeinsam nutzen: Umschlag, Etikett, Paket-Fortschritt.

/// Umschlag: das Bild von der Post auf Papier – ohne Bild ein Symbol auf getönter Fläche.
struct Umschlag: View {
    let brief: Brief
    var bild: NSImage?
    var eckradius: CGFloat = 10

    var body: some View {
        let form = RoundedRectangle(cornerRadius: eckradius, style: .continuous)
        ZStack {
            if let bild {
                Color(red: 0.985, green: 0.976, blue: 0.953)
                Image(nsImage: bild)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(3)
            } else {
                LinearGradient(colors: brief.paket ? [Color(red: 0.84, green: 0.64, blue: 0.42), Color(red: 0.72, green: 0.52, blue: 0.3)]
                               : [Color.primary.opacity(0.07), Color.primary.opacity(0.03)], startPoint: .top, endPoint: .bottom)
                Image(systemName: brief.paket ? "shippingbox.fill" : brief.wichtig ? "envelope.badge.fill" : "envelope.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 64, maxHeight: 44)
                    .foregroundStyle(brief.paket ? AnyShapeStyle(Color.white.opacity(0.9)) : brief.wichtig ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .clipShape(form)
        .overlay(form.strokeBorder(brief.wichtig && !brief.istErledigt ? Color.red.opacity(0.85) : Color.primary.opacity(0.12),
                                   lineWidth: brief.wichtig && !brief.istErledigt ? 2 : 0.5))
        .accessibilityHidden(true)
    }
}

/// Kleines farbiges Etikett wie „Heute“ oder „Wichtig“
struct Etikett: View {
    let text: String
    var farbe: Color = .accentColor
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(farbe)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(farbe.opacity(0.16), in: Capsule())
            .fixedSize()
    }
}

/// Paket: unterwegs · kommt heute · zugestellt
struct PaketFortschritt: View {
    let brief: Brief
    var hoehe: CGFloat = 5
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(i <= brief.stufe ? Color.green : Color.primary.opacity(0.18))
                    .frame(width: i == 1 ? hoehe : hoehe * 2.6, height: hoehe)
            }
        }
        .accessibilityLabel(brief.stand == "zugestellt" ? T("zugestellt") : brief.stand == "heute" ? T("kommt heute") : T("unterwegs"))
    }
}

/// Etiketten eines Briefs (Heute, Wichtig)
struct BriefEtiketten: View {
    let brief: Brief
    var jetzt = Date()
    var body: some View {
        HStack(spacing: 4) {
            if Calendar.current.isDate(brief.datum, inSameDayAs: jetzt) && !brief.istErledigt { Etikett(text: T("Heute")) }
            if brief.wichtig { Etikett(text: T("Wichtig"), farbe: .red) }
        }
    }
}

extension View {
    /// Liquid Glass ab macOS 26, sonst Material
    @ViewBuilder
    func glasFlaeche<S: Shape>(_ form: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: form)
        } else {
            self.background(.regularMaterial, in: form)
        }
    }
}
