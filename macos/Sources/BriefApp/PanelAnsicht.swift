import SwiftUI
import BriefLogik

/// Panel aus der Menüleiste: Kopf, darunter Karten zum Durchblättern oder die Liste.
struct PanelAnsicht: View {
    let kern: Kern
    var oeffnen: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 10) {
            PostKopf(kern: kern, oeffnen: oeffnen, mitModus: true)
            PostHinweise(kern: kern, oeffnen: oeffnen)
            if kern.ha.post != nil {
                if kern.einstellungen.modus == "liste" || kern.gruppen.offen.isEmpty {
                    BriefListe(kern: kern)
                } else {
                    KartenBand(kern: kern, briefe: kern.gruppen.offen)
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(width: 400, height: 580)
    }
}

/// Eigenes Fenster: Karten links, Liste rechts
struct BriefeFenster: View {
    let kern: Kern
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            PostKopf(kern: kern, oeffnen: { openWindow(id: $0) }, mitModus: false)
            PostHinweise(kern: kern, oeffnen: { openWindow(id: $0) })
            if kern.ha.post != nil {
                HStack(alignment: .top, spacing: 16) {
                    if !kern.gruppen.offen.isEmpty {
                        KartenBand(kern: kern, briefe: kern.gruppen.offen)
                            .frame(minWidth: 320, idealWidth: 400, maxWidth: 520)
                    }
                    BriefListe(kern: kern)
                        .frame(minWidth: 300)
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(minWidth: 640, minHeight: 460)
    }
}

/// Kopf: Symbol, Anzahl, Stand; Karten/Liste, Nachsehen, Menü
struct PostKopf: View {
    let kern: Kern
    let oeffnen: (String) -> Void
    var mitModus: Bool

    var body: some View {
        let g = kern.gruppen
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.accentColor.gradient)
                Image(systemName: g.heute.isEmpty ? "envelope.fill" : "envelope.badge.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(kern.ha.post != nil ? PostText.titel(g.offen) : T("Briefankündigung"))
                    .font(.headline)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text(unterzeile(g))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            GlasGruppe(abstand: 6) {
                HStack(spacing: 6) {
                    if mitModus && kern.ha.post != nil && !g.offen.isEmpty {
                        Button {
                            withAnimation(.snappy) { kern.einstellungen.modus = kern.einstellungen.modus == "liste" ? "karten" : "liste" }
                        } label: {
                            Image(systemName: kern.einstellungen.modus == "liste" ? "rectangle.stack" : "list.bullet")
                                .frame(width: 16, height: 16)
                        }
                        .help(kern.einstellungen.modus == "liste" ? T("Als Karten") : T("Als Liste"))
                        .glasKnopf()
                    }
                    if kern.einstellungen.eingerichtet && !kern.ha.fehltIntegration {
                        Button { kern.ha.jetztNachsehen() } label: {
                            Group {
                                if kern.ha.nachsehen { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.clockwise") }
                            }
                            .frame(width: 16, height: 16)
                        }
                        .help(T("Home Assistant jetzt ins Postfach schauen lassen"))
                        .disabled(kern.ha.nachsehen)
                        .glasKnopf()
                    }
                    Menu {
                        Button(T("Alle Briefe im Fenster …")) { oeffnen("briefe") }
                        Button(T("Einstellungen …")) { oeffnen("einstellungen") }
                        Divider()
                        Button(kern.aktualisierer.neueVersion.map { T("Update auf %1 …", $0) } ?? T("Was ist neu?")) {
                            if kern.aktualisierer.notizen.isEmpty { Task { await kern.aktualisierer.pruefen() } }
                            oeffnen("neuigkeiten")
                        }
                        if let u = URL(string: kern.ha.adresse), !kern.ha.adresse.isEmpty {
                            Button(T("Home Assistant öffnen")) { NSWorkspace.shared.open(u) }
                        }
                        Divider()
                        Button(T("Beenden")) { NSApp.terminate(nil) }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 16, height: 16)
                    }
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .glasKnopf()
                }
            }
        }
    }

    private func unterzeile(_ g: Gruppen) -> String {
        guard let p = kern.ha.gezeigt else { return kern.einstellungen.eingerichtet ? T("Verbinde …") : "" }
        var teile: [String] = []
        if !g.heute.isEmpty { teile.append(T("%1 heute", "\(g.heute.count)")) }
        if let s = p.stand { teile.append(T("gelesen %1", PostText.vor(s))) }
        if let n = p.naechsterAbruf { teile.append(T("nächstes Mal %1", n.formatted(date: .omitted, time: .shortened))) }
        return teile.joined(separator: " · ")
    }
}

/// Einrichten, Fehler, Update verfügbar
struct PostHinweise: View {
    let kern: Kern
    let oeffnen: (String) -> Void

    var body: some View {
        if !kern.einstellungen.eingerichtet {
            Hinweis(symbol: "gearshape", titel: T("Noch nicht eingerichtet"),
                    text: T("Adresse von Home Assistant und ein Token eintragen – die Integration „Briefankündigung“ liefert die Briefe."),
                    knopf: T("Einrichten …")) { oeffnen("einstellungen") }
        } else if kern.ha.post == nil && !kern.ha.fehler.isEmpty {
            Hinweis(symbol: kern.ha.fehltIntegration ? "shippingbox" : "wifi.exclamationmark",
                    titel: kern.ha.fehltIntegration ? T("Integration fehlt") : T("Keine Verbindung"), text: kern.ha.fehler,
                    knopf: kern.ha.fehltIntegration ? T("Integration ansehen") : T("Erneut versuchen")) {
                if kern.ha.fehltIntegration { NSWorkspace.shared.open(URL(string: "https://github.com/Teyro/Briefankuendigung-HA")!) } else { kern.ha.erneutVersuchen() }
            }
        } else if kern.ha.post == nil {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        if let fehler = kern.ha.gezeigt?.fehler, !fehler.isEmpty {
            Label(T("Postfach: %1", fehler), systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading)
        }
        if !kern.ha.meldung.isEmpty {
            Label(kern.ha.meldung, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                .task { try? await Task.sleep(for: .seconds(6)); kern.ha.meldung = "" }
        }
        if let v = kern.aktualisierer.neueVersion {
            HStack {
                Label(T("Version %1 ist verfügbar.", v), systemImage: "arrow.down.circle.fill").font(.callout)
                Spacer()
                Button(T("Ansehen")) { oeffnen("neuigkeiten") }.glasKnopf().controlSize(.small)
            }
            .karte(farbe: .accentColor, eckradius: 12)
        }
    }
}

struct Hinweis: View {
    let symbol: String
    let titel: String
    let text: String
    let knopf: String
    let aktion: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: symbol).font(.system(size: 38, weight: .light)).foregroundStyle(.secondary)
            Text(titel).font(.title3.weight(.semibold))
            Text(text).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 300)
            Button(knopf, action: aktion).glasKnopfBetont()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Karten

/// Karten zum Durchblättern: wischen (Trackpad/Maus), ‹ ›, Punkte; blättert auf Wunsch von selbst weiter.
struct KartenBand: View {
    let kern: Kern
    let briefe: [Brief]
    @State private var index = 0
    @State private var richtung: Edge = .trailing
    @State private var ueber = false
    @State private var pauseBis = Date.distantPast
    @GestureState private var zug: CGFloat = 0

    var body: some View {
        let i = briefe.isEmpty ? 0 : min(index, briefe.count - 1)
        VStack(spacing: 10) {
            ZStack {
                if !briefe.isEmpty {
                    BriefKarte(kern: kern, brief: briefe[i])
                        .id(briefe[i].id)
                        .transition(.asymmetric(insertion: .move(edge: richtung).combined(with: .opacity),
                                                removal: .move(edge: richtung == .trailing ? .leading : .trailing).combined(with: .opacity)))
                        .offset(x: zug * 0.4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 20)
                .updating($zug) { w, s, _ in s = w.translation.width }
                .onEnded { w in if abs(w.translation.width) > 50 { blaettern(w.translation.width < 0 ? 1 : -1) } })

            if briefe.count > 1 {
                HStack(spacing: 10) {
                    Button { blaettern(-1) } label: { Image(systemName: "chevron.left").frame(width: 14, height: 14) }
                        .glasKnopf().help(T("Vorheriger Brief"))
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<min(briefe.count, 12), id: \.self) { n in
                            Circle()
                                .fill(n == i ? Color.primary.opacity(0.8) : Color.primary.opacity(0.2))
                                .frame(width: 7, height: 7)
                                .onTapGesture { springen(n) }
                        }
                    }
                    Spacer()
                    Button { blaettern(1) } label: { Image(systemName: "chevron.right").frame(width: 14, height: 14) }
                        .glasKnopf().help(T("Nächster Brief"))
                }
            }
        }
        .onHover { ueber = $0 }
        .task(id: briefe.map(\.id)) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(9))
                if kern.einstellungen.automatisch && !ueber && Date() > pauseBis && briefe.count > 1 {
                    richtung = .trailing
                    withAnimation(.smooth(duration: 0.45)) { index = PostText.blaettern(index, 1, briefe.count) }
                }
            }
        }
    }

    private func blaettern(_ schritt: Int) {
        richtung = schritt > 0 ? .trailing : .leading
        pauseBis = Date().addingTimeInterval(30)
        withAnimation(.smooth(duration: 0.4)) { index = PostText.blaettern(min(index, max(0, briefe.count - 1)), schritt, briefe.count) }
    }

    private func springen(_ n: Int) {
        richtung = n > index ? .trailing : .leading
        pauseBis = Date().addingTimeInterval(30)
        withAnimation(.smooth(duration: 0.4)) { index = n }
    }
}

/// Eine Karte: Umschlag groß, Absender, Stand, Aktionen
struct BriefKarte: View {
    let kern: Kern
    let brief: Brief

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Umschlag(brief: brief, bild: kern.ha.bilder[brief.id], eckradius: 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            BriefEtiketten(brief: brief)
            Text(brief.absenderText)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            HStack(spacing: 8) {
                if brief.paket { PaketFortschritt(brief: brief, hoehe: 6) }
                Text(PostText.unterzeile(brief, mitKonto: kern.ha.gezeigt?.mehrereKonten ?? false))
                    .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
                AktionsKnoepfe(kern: kern, brief: brief)
            }
        }
        .padding(12)
        .glas(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct AktionsKnoepfe: View {
    let kern: Kern
    let brief: Brief
    var body: some View {
        HStack(spacing: 6) {
            if !brief.sendung.isEmpty, let u = PostText.dhl(brief.sendung) {
                Button { NSWorkspace.shared.open(u) } label: { Image(systemName: "location.magnifyingglass") }
                    .help(T("Verfolgen")).glasKnopf()
            }
            if !(brief.paket && brief.stand == "zugestellt") {
                if brief.erledigt {
                    Button { kern.ha.abhaken(brief.id, false) } label: { Image(systemName: "arrow.uturn.backward") }
                        .help(T("Doch nicht angekommen")).glasKnopf()
                } else {
                    Button { withAnimation(.snappy) { kern.ha.abhaken(brief.id, true) } } label: { Label(T("Angekommen"), systemImage: "checkmark") }
                        .labelStyle(.iconOnly)
                        .help(T("Angekommen")).glasKnopfBetont()
                }
            }
        }
        .controlSize(.small)
    }
}

// MARK: - Liste

struct BriefListe: View {
    let kern: Kern
    @State private var heuteOffen = true
    @State private var unterwegsOffen = true
    @State private var angekommenOffen = false
    @State private var offen: String?

    var body: some View {
        let g = kern.gruppen
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if !g.heute.isEmpty {
                    Abschnitt(titel: T("Heute"), anzahl: g.heute.count, offen: $heuteOffen)
                    if heuteOffen { ForEach(g.heute) { zeile($0) } }
                }
                if !g.unterwegs.isEmpty {
                    Abschnitt(titel: T("Noch unterwegs"), anzahl: g.unterwegs.count, offen: $unterwegsOffen)
                    if unterwegsOffen { ForEach(g.unterwegs) { zeile($0) } }
                }
                if !g.angekommen.isEmpty {
                    Abschnitt(titel: T("Angekommen"), anzahl: g.angekommen.count, offen: $angekommenOffen)
                    if angekommenOffen { ForEach(g.angekommen) { zeile($0) } }
                }
                if g.offen.isEmpty && g.angekommen.isEmpty {
                    Hinweis(symbol: "tray", titel: T("Keine Post angekündigt"),
                            text: T("Sobald die Deutsche Post einen Brief ankündigt, erscheint er hier mit Bild des Umschlags."),
                            knopf: T("Jetzt nachsehen")) { kern.ha.jetztNachsehen() }
                        .frame(minHeight: 300)
                }
            }
        }
        .scrollIndicators(.automatic)
    }

    private func zeile(_ b: Brief) -> some View {
        BriefZeile(kern: kern, brief: b, aufgeklappt: offen == b.id) {
            withAnimation(.snappy) { offen = offen == b.id ? nil : b.id }
        }
    }
}

struct BriefZeile: View {
    let kern: Kern
    let brief: Brief
    let aufgeklappt: Bool
    let umschalten: () -> Void
    @State private var ueber = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Umschlag(brief: brief, bild: kern.ha.bilder[brief.id], eckradius: 7)
                    .frame(width: 64, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        BriefEtiketten(brief: brief)
                        Text(brief.absenderText).font(.system(size: 13, weight: brief.istErledigt ? .regular : .semibold)).lineLimit(1)
                    }
                    HStack(spacing: 5) {
                        if brief.paket { PaketFortschritt(brief: brief) }
                        Text(PostText.unterzeile(brief, mitKonto: kern.ha.gezeigt?.mehrereKonten ?? false))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                AktionsKnoepfe(kern: kern, brief: brief)
            }
            if aufgeklappt {
                if let bild = kern.ha.bilder[brief.id] {
                    Umschlag(brief: brief, bild: bild, eckradius: 12)
                        .frame(height: 190)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Text(T("angekündigt %1", brief.datum.formatted(date: .abbreviated, time: .shortened))
                     + (brief.sendung.isEmpty ? "" : " · " + T("Sendung %1", brief.sendung))
                     + (brief.kontoName.isEmpty ? "" : " · " + brief.kontoName))
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .padding(8)
        .opacity(brief.istErledigt ? 0.6 : 1)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(ueber || aufgeklappt ? 0.07 : 0)))
        .contentShape(Rectangle())
        .onHover { ueber = $0 }
        .onTapGesture(perform: umschalten)
        .accessibilityElement(children: .combine)
    }
}
