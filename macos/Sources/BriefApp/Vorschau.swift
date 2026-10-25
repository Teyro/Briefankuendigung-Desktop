import SwiftUI
import BriefLogik

/// Testlauf für die automatischen Bildschirmfotos (GitHub Actions):
/// `Briefankuendigung --vorschau Dark|Light` mit BA_ADRESSE, BA_TOKEN, BA_BILDER, BA_UPDATE_URL.
@MainActor
enum Vorschau {
    static var fenster: [NSWindow] = []

    static func starten(_ kern: Kern) {
        let args = CommandLine.arguments
        let modus = args.firstIndex(of: "--vorschau").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "Light"
        NSApp.appearance = NSAppearance(named: modus == "Dark" ? .darkAqua : .aqua)
        let ordner = ProcessInfo.processInfo.environment["BA_BILDER"] ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: ordner, withIntermediateDirectories: true)

        let f = fensterMit(PanelAnsicht(kern: kern).background(Hintergrund()), titel: T("Briefankündigung"), groesse: NSSize(width: 400, height: 580))
        f.setFrameOrigin(NSPoint(x: 60, y: 80))

        Task {
            func warte(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
            @MainActor func foto(_ fenster: NSWindow, _ name: String) { speichern(fenster, "\(ordner)/\(modus)_\(name).png") }
            await warte(5)
            print("briefe:", kern.ha.post?.briefe.count ?? -1, "bilder:", kern.ha.bilder.count, "fehler:", kern.ha.fehler)
            if let name = ProcessInfo.processInfo.environment["BA_NUR_ERSTES"] {
                foto(f, name)
                await warte(20)
                NSApp.terminate(nil)
                return
            }
            foto(f, "1_karten")
            kern.einstellungen.modus = "liste"
            await warte(1.5)
            foto(f, "2_liste")
            kern.ha.abhaken(String(repeating: "b", count: 20), true)
            await warte(2)
            foto(f, "3_abgehakt")
            kern.ha.abhaken(String(repeating: "b", count: 20), false)
            kern.einstellungen.modus = "karten"

            // Pakete: Karten, Liste, Formular „Sendung verfolgen“
            kern.bereich = "pakete"
            await warte(1.5)
            foto(f, "3a_pakete")
            kern.einstellungen.modus = "liste"
            kern.formular = true
            await warte(1.5)
            foto(f, "3b_pakete_liste")
            kern.formular = false
            kern.einstellungen.modus = "karten"
            kern.bereich = "briefe"

            let b = fensterMit(BriefeFenster(kern: kern).background(Hintergrund()), titel: T("Briefankündigung"), groesse: NSSize(width: 780, height: 620))
            b.setFrameOrigin(NSPoint(x: 480, y: 60))
            await warte(2)
            foto(b, "4_fenster")
            b.orderOut(nil)

            // Widgets wie auf dem Schreibtisch (gleiche Ansichten wie in der Widget-Erweiterung)
            kern.widgetsAktualisieren(sofort: true)
            await warte(1)
            let daten = WidgetDaten.lesen() ?? WidgetDaten()
            print("widgets:", daten.offen.count, "offen,", daten.heute, "heute, bilder:", daten.offen.filter { WidgetDaten.bild($0.id) != nil }.count)
            let w = fensterMit(WidgetVorschau(daten: daten).background(Hintergrund()), titel: T("Widgets"), groesse: NSSize(width: 800, height: 640))
            w.setFrameOrigin(NSPoint(x: 480, y: 40))
            await warte(2)
            foto(w, "5_widgets")
            w.orderOut(nil)
            let pw = fensterMit(WidgetVorschau(daten: daten, pakete: true).background(Hintergrund()), titel: T("Pakete"), groesse: NSSize(width: 800, height: 640))
            pw.setFrameOrigin(NSPoint(x: 480, y: 40))
            await warte(2)
            foto(pw, "5a_pakete_widgets")
            pw.orderOut(nil)

            let e = fensterMit(EinstellungenAnsicht(kern: kern), titel: T("Briefankündigung – Einstellungen"), groesse: NSSize(width: 520, height: 600))
            e.setFrameOrigin(NSPoint(x: 480, y: 40))
            await warte(2.5)
            foto(e, "6_einstellungen")
            e.orderOut(nil)

            await kern.aktualisierer.pruefen()
            print("update:", kern.aktualisierer.neueVersion ?? "-", kern.aktualisierer.downloadURL?.absoluteString ?? "-")
            await warte(1)
            foto(f, "7_update_hinweis")
            let n = fensterMit(NeuigkeitenAnsicht(akt: kern.aktualisierer), titel: T("Briefankündigung – Was ist neu?"), groesse: NSSize(width: 520, height: 520))
            n.setFrameOrigin(NSPoint(x: 480, y: 120))
            await warte(1.5)
            foto(n, "8_neuigkeiten")
            NSApp.terminate(nil)
        }
    }

    private static func fensterMit<V: View>(_ inhalt: V, titel: String, groesse: NSSize) -> NSWindow {
        let f = NSWindow(contentRect: NSRect(origin: .zero, size: groesse), styleMask: [.titled, .fullSizeContentView],
                         backing: .buffered, defer: false)
        f.title = titel
        f.titlebarAppearsTransparent = true
        f.contentView = NSHostingView(rootView: inhalt)
        f.makeKeyAndOrderFront(nil)
        fenster.append(f)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        return f
    }

    /// Fenster als Bild speichern: per screencapture (echtes Glas), sonst aus der Ansicht selbst
    private static func speichern(_ f: NSWindow, _ pfad: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-o", "-l\(f.windowNumber)", pfad]
        try? p.run()
        p.waitUntilExit()
        if p.terminationStatus == 0, FileManager.default.fileExists(atPath: pfad) {
            print("Bild", pfad)
            return
        }
        guard let v = f.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
        v.cacheDisplay(in: v.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: pfad))
        print("Bild (Ansicht)", pfad)
    }
}

/// Alle Widgets in ihren echten Größen (klein 170×170, mittel 364×170, groß 364×382)
private struct WidgetVorschau: View {
    let daten: WidgetDaten
    var pakete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                kachel(170, 170) { KleinesWidget(daten: daten, pakete: pakete) }
                kachel(364, 170) { KartenWidget(daten: daten, pakete: pakete, index: 0, interaktiv: false) }
            }
            HStack(alignment: .top, spacing: 16) {
                kachel(364, 382) { ListenWidget(daten: daten, pakete: pakete) }
                VStack(spacing: 16) {
                    kachel(364, 170) { KartenWidget(daten: daten, pakete: pakete, index: pakete ? 1 : 3, interaktiv: false) }
                    kachel(170, 170) { KleinesWidget(daten: WidgetDaten(), pakete: pakete) }
                }
            }
        }
        .padding(20)
    }

    private func kachel<V: View>(_ b: CGFloat, _ h: CGFloat, @ViewBuilder inhalt: () -> V) -> some View {
        inhalt()
            .padding(14)
            .frame(width: b, height: h, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }
}

/// Farbverlauf als Ersatz für das Schreibtischbild
private struct Hintergrund: View {
    @Environment(\.colorScheme) private var schema
    var body: some View {
        LinearGradient(colors: schema == .dark
                       ? [Color(red: 0.12, green: 0.14, blue: 0.3), Color(red: 0.25, green: 0.1, blue: 0.3), Color(red: 0.05, green: 0.2, blue: 0.25)]
                       : [Color(red: 0.75, green: 0.85, blue: 1.0), Color(red: 0.95, green: 0.8, blue: 0.9), Color(red: 0.8, green: 0.95, blue: 0.9)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}
