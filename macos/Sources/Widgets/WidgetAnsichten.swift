import SwiftUI
import AppIntents
import BriefLogik

/// Größe des Widgets (unabhängig von WidgetKit, damit die App die Ansichten für die Vorschau nutzen kann)
enum WidgetGroesse { case klein, mittel, gross }

private func umschlagBild(_ b: Brief) -> NSImage? {
    WidgetDaten.bild(b.id).flatMap { NSImage(contentsOf: $0) }
}

extension WidgetDaten {
    /// Was ein Widget zeigt: alle offenen Sendungen oder nur die Pakete
    func liste(_ pakete: Bool) -> [Brief] { pakete ? self.pakete : offen }
    func heuteZahl(_ pakete: Bool) -> Int { pakete ? paketeHeute : heute }
}

/// Kopf: Briefsymbol, Anzahl, rechts „2 heute“
struct WidgetKopf: View {
    let daten: WidgetDaten
    var kompakt = false
    var pakete = false
    var body: some View {
        let liste = daten.liste(pakete), heute = daten.heuteZahl(pakete)
        HStack(spacing: 6) {
            Image(systemName: pakete ? "shippingbox.fill" : heute > 0 ? "envelope.badge.fill" : "envelope.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: kompakt ? 13 : 15, weight: .semibold))
            Text(kompakt ? (liste.isEmpty ? (pakete ? T("Pakete") : T("Post")) : T("%1 unterwegs", "\(liste.count)"))
                 : pakete ? PostText.paketTitel(liste) : PostText.titel(liste))
                .font(.system(size: kompakt ? 12 : 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            if heute > 0 {
                Text(T("%1 heute", "\(heute)"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 1.5)
                    .background(Color.accentColor, in: Capsule())
                    .fixedSize()
            }
        }
    }
}

/// Hinweis, wenn nichts unterwegs ist oder etwas fehlt
struct WidgetLeer: View {
    let daten: WidgetDaten
    var pakete = false
    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Image(systemName: !daten.eingerichtet ? "gearshape" : !daten.fehler.isEmpty ? "exclamationmark.triangle" : pakete ? "shippingbox" : "tray")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)
            Text(!daten.eingerichtet ? T("App öffnen und einrichten") : !daten.fehler.isEmpty ? daten.fehler : pakete ? T("Keine Pakete unterwegs") : T("Keine Post unterwegs"))
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .foregroundStyle(.secondary)
            if daten.fehler.isEmpty, !pakete, let z = daten.zuletzt {
                Text(T("Zuletzt: %1 (%2)", z.absenderText, PostText.datum(z.datum)))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Klein: der wichtigste/neueste Brief mit Umschlag
struct KleinesWidget: View {
    let daten: WidgetDaten
    var pakete = false
    private var liste: [Brief] { daten.liste(pakete) }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetKopf(daten: daten, pakete: pakete, kompakt: true)
            if let b = liste.first {
                Umschlag(brief: b, bild: umschlagBild(b), eckradius: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 1) {
                    Text(b.absenderText).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(PostText.unterzeile(b) + (liste.count > 1 ? " · +\(liste.count - 1)" : ""))
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                WidgetLeer(daten: daten, pakete: pakete)
            }
        }
    }
}

/// Mittel: Karten zum Durchblättern (‹ ›) mit „Angekommen“
struct KartenWidget: View {
    let daten: WidgetDaten
    var pakete = false
    private var liste: [Brief] { daten.liste(pakete) }
    let index: Int
    var interaktiv = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetKopf(daten: daten, pakete: pakete)
            if liste.isEmpty {
                WidgetLeer(daten: daten, pakete: pakete)
            } else {
                let i = min(max(0, index), liste.count - 1)
                let b = liste[i]
                HStack(spacing: 12) {
                    Umschlag(brief: b, bild: umschlagBild(b), eckradius: 10)
                        .frame(width: 136)
                    VStack(alignment: .leading, spacing: 4) {
                        BriefEtiketten(brief: b)
                        Text(b.absenderText)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: 5) {
                            if b.paket { PaketFortschritt(brief: b) }
                            Text(PostText.unterzeile(b, mitKonto: daten.mehrereKonten)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 6) {
                            knopf("chevron.left", BlaetternAbsicht(-1, pakete: pakete), aktiv: liste.count > 1)
                            Text("\(i + 1)/\(liste.count)").font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
                            knopf("chevron.right", BlaetternAbsicht(1, pakete: pakete), aktiv: liste.count > 1)
                            Spacer(minLength: 0)
                            if pakete, let u = b.verfolgenURL {
                                Link(destination: u) {
                                    Image(systemName: "location.magnifyingglass").font(.system(size: 11, weight: .bold))
                                        .frame(width: 24, height: 22).background(Color.primary.opacity(0.08), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            if !(b.paket && b.stand == "zugestellt") { knopf("checkmark", AngekommenAbsicht(b.id), aktiv: true, betont: true) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func knopf<I: AppIntent>(_ symbol: String, _ absicht: I, aktiv: Bool, betont: Bool = false) -> some View {
        let bild = Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .frame(width: 24, height: 22)
            .background((betont ? Color.accentColor : Color.primary).opacity(betont ? 0.2 : 0.08), in: Capsule())
            .foregroundStyle(betont ? Color.accentColor : .primary)
            .opacity(aktiv ? 1 : 0.35)
        if interaktiv && aktiv {
            Button(intent: absicht) { bild }.buttonStyle(.plain)
        } else {
            bild
        }
    }
}

/// Groß: Liste mit Umschlägen
struct ListenWidget: View {
    let daten: WidgetDaten
    var pakete = false
    private var liste: [Brief] { daten.liste(pakete) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetKopf(daten: daten, pakete: pakete)
            if liste.isEmpty {
                WidgetLeer(daten: daten, pakete: pakete)
            } else {
                ForEach(liste.prefix(5)) { b in
                    HStack(spacing: 10) {
                        Umschlag(brief: b, bild: umschlagBild(b), eckradius: 7)
                            .frame(width: 74, height: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                BriefEtiketten(brief: b)
                                Text(b.absenderText).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            }
                            HStack(spacing: 5) {
                                if b.paket { PaketFortschritt(brief: b) }
                                Text(PostText.unterzeile(b, mitKonto: daten.mehrereKonten)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    if liste.count > 5 { Text(T("+ %1 weitere", "\(liste.count - 5)")) }
                    Spacer()
                    if let g = daten.gelesen { Text(T("gelesen %1", PostText.vor(g))) }
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
    }
}
