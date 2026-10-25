import SwiftUI
import AppIntents
import BriefLogik

/// Größe des Widgets (unabhängig von WidgetKit, damit die App die Ansichten für die Vorschau nutzen kann)
enum WidgetGroesse { case klein, mittel, gross }

private func umschlagBild(_ b: Brief) -> NSImage? {
    WidgetDaten.bild(b.id).flatMap { NSImage(contentsOf: $0) }
}

/// Kopf: Briefsymbol, Anzahl, rechts „2 heute“
struct WidgetKopf: View {
    let daten: WidgetDaten
    var kompakt = false
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: daten.heute > 0 ? "envelope.badge.fill" : "envelope.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: kompakt ? 13 : 15, weight: .semibold))
            Text(kompakt ? (daten.offen.isEmpty ? T("Post") : T("%1 unterwegs", "\(daten.offen.count)")) : PostText.titel(daten.offen))
                .font(.system(size: kompakt ? 12 : 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            if daten.heute > 0 {
                Text(T("%1 heute", "\(daten.heute)"))
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
    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Image(systemName: !daten.eingerichtet ? "gearshape" : !daten.fehler.isEmpty ? "exclamationmark.triangle" : "tray")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)
            Text(!daten.eingerichtet ? T("App öffnen und einrichten") : !daten.fehler.isEmpty ? daten.fehler : T("Keine Post unterwegs"))
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .foregroundStyle(.secondary)
            if daten.fehler.isEmpty, let z = daten.zuletzt {
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
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetKopf(daten: daten, kompakt: true)
            if let b = daten.offen.first {
                Umschlag(brief: b, bild: umschlagBild(b), eckradius: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 1) {
                    Text(b.absenderText).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(PostText.unterzeile(b) + (daten.offen.count > 1 ? " · +\(daten.offen.count - 1)" : ""))
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                WidgetLeer(daten: daten)
            }
        }
    }
}

/// Mittel: Karten zum Durchblättern (‹ ›) mit „Angekommen“
struct KartenWidget: View {
    let daten: WidgetDaten
    let index: Int
    var interaktiv = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetKopf(daten: daten)
            if daten.offen.isEmpty {
                WidgetLeer(daten: daten)
            } else {
                let i = min(max(0, index), daten.offen.count - 1)
                let b = daten.offen[i]
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
                            knopf("chevron.left", BlaetternAbsicht(-1), aktiv: daten.offen.count > 1)
                            Text("\(i + 1)/\(daten.offen.count)").font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
                            knopf("chevron.right", BlaetternAbsicht(1), aktiv: daten.offen.count > 1)
                            Spacer(minLength: 0)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetKopf(daten: daten)
            if daten.offen.isEmpty {
                WidgetLeer(daten: daten)
            } else {
                ForEach(daten.offen.prefix(5)) { b in
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
                    if daten.offen.count > 5 { Text(T("+ %1 weitere", "\(daten.offen.count - 5)")) }
                    Spacer()
                    if let g = daten.gelesen { Text(T("gelesen %1", PostText.vor(g))) }
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
    }
}
