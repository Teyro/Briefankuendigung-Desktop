import SwiftUI
import BriefLogik

/// Liquid Glass ab macOS 26, davor das bisherige Material – überall die gleiche Schreibweise.
extension View {
    @ViewBuilder
    func glas<S: Shape>(_ form: S, farbe: Color? = nil, interaktiv: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(Self.glasArt(farbe, interaktiv), in: form)
        } else {
            self.background {
                ZStack {
                    form.fill(.regularMaterial)
                    if let farbe { form.fill(farbe.opacity(0.22)) }
                    form.stroke(.white.opacity(0.12), lineWidth: 0.5)
                }
            }
        }
    }

    @available(macOS 26.0, *)
    private static func glasArt(_ farbe: Color?, _ interaktiv: Bool) -> Glass {
        var g = Glass.regular
        if let farbe { g = g.tint(farbe) }
        if interaktiv { g = g.interactive() }
        return g
    }

    /// Karte: abgerundetes Glas mit Innenabstand
    func karte(farbe: Color? = nil, eckradius: CGFloat = 16) -> some View {
        self.padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glas(RoundedRectangle(cornerRadius: eckradius, style: .continuous), farbe: farbe)
    }

    /// Runde Glasknöpfe (Werkzeugleiste)
    @ViewBuilder
    func glasKnopf() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func glasKnopfBetont() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

/// Mehrere Glasflächen zusammen zeichnen (ab macOS 26 verschmelzen sie weich ineinander)
struct GlasGruppe<Inhalt: View>: View {
    var abstand: CGFloat = 8
    @ViewBuilder var inhalt: Inhalt
    var body: some View {
        if #available(macOS 26.0, *) {

/// Abschnittsüberschrift, optional zum Auf- und Zuklappen und mit Anzahl
struct Abschnitt: View {
    let titel: String
    var symbol: String?
    var anzahl: Int?
    var offen: Binding<Bool>?

    var body: some View {
        if let offen {
            Button {
                withAnimation(.snappy) { offen.wrappedValue.toggle() }
            } label: {
                zeile(offen: offen.wrappedValue)
            }
            .buttonStyle(.plain)
        } else {
            zeile(offen: nil)
        }
    }

    private func zeile(offen: Bool?) -> some View {
        HStack(spacing: 6) {
            if let offen {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .heavy))
                    .rotationEffect(.degrees(offen ? 90 : 0))
            }
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .semibold)) }
            Text(titel.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
            if let anzahl {
                Text("\(anzahl)")
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.primary.opacity(0.08), in: Capsule())
            }
            Spacer()
        }
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .padding(.bottom, 1)
    }
}
