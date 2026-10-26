import SwiftUI
import WidgetKit
import BriefLogik

/// Briefankündigung für macOS: angekündigte Briefe und Pakete aus Home Assistant –
/// in der Menüleiste, als eigenes Fenster und als Widgets auf dem Schreibtisch.
@main
struct BriefApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var kern = Kern.shared

    var body: some Scene {
        MenuBarExtra {
            PanelMitFenster(kern: kern)
        } label: {
            MenueSymbol(kern: kern)
        }
        .menuBarExtraStyle(.window)

        Window(T("Briefankündigung"), id: "briefe") {
            BriefeFenster(kern: kern)
        }
        .defaultSize(width: 760, height: 620)
        .defaultPosition(.center)

        Window(T("Briefankündigung – Einstellungen"), id: "einstellungen") {
            EinstellungenAnsicht(kern: kern)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window(T("Briefankündigung – Was ist neu?"), id: "neuigkeiten") {
            NeuigkeitenAnsicht(akt: kern.aktualisierer)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// Alles, was die App einmal braucht: Einstellungen, Verbindung, Updates, Widgets.
@MainActor
@Observable
final class Kern {
    static let shared = Kern()

    let vorschau = CommandLine.arguments.contains("--vorschau")
    let einstellungen: Einstellungen
    let ha = Verbindung()
    let aktualisierer = Aktualisierer()
    /// Aus Widgets und Mitteilungen: Fenster öffnen (gesetzt von einer Ansicht mit openWindow)
    @ObservationIgnored var fensterOeffnen: (String) -> Void = { _ in }
    @ObservationIgnored private var letzteWidgetDaten: WidgetDaten?
    @ObservationIgnored private var verzoegert: Task<Void, Never>?

    var gezeigt: Post? { ha.gezeigt }
    var gruppen: Gruppen { Gruppen(ha.gezeigt?.briefe ?? []) }
    var briefGruppen: Gruppen { Gruppen((ha.gezeigt?.briefe ?? []).filter { !$0.paket }) }
    var paketGruppen: Gruppen { Gruppen.pakete(ha.gezeigt?.briefe ?? []) }
    /// Gibt es überhaupt Pakete? Dann zeigen Panel und Fenster „Briefe | Pakete“
    var mitPaketen: Bool { ha.gezeigt?.briefe.contains(where: \.paket) ?? false }
    /// "briefe" oder "pakete"
    var bereich = "briefe"
    /// Formular „Sendung verfolgen“ offen
    var formular = false
    var paketAnsicht: Bool { mitPaketen && bereich == "pakete" }
    /// Gezeigte Gruppen (Panel, Fenster)
    var ansicht: Gruppen { !mitPaketen ? gruppen : paketAnsicht ? paketGruppen : briefGruppen }

    private init() {
        Sprache.laden()
        einstellungen = Einstellungen(vorschau: vorschau)
        einstellungen.geaendert = { [weak self] in self?.uebernehmen() }
        ha.nachLaden = { [weak self] in self?.widgetsAktualisieren() }
        if vorschau {
            let env = ProcessInfo.processInfo.environment
            einstellungen.adresse = env["BA_ADRESSE"] ?? "http://127.0.0.1:8123"
            einstellungen.token = env["BA_TOKEN"] ?? "test-token"
            if let u = env["BA_UPDATE_URL"], let url = URL(string: u) { aktualisierer.quelle = url }
        }
        uebernehmen(sofort: true)
        befehleEmpfangen()
        Task { await self.dauerlauf() }
        if einstellungen.updatesSuchen && !vorschau {
            Task {
                try? await Task.sleep(for: .seconds(20))
                await self.aktualisierer.automatischPruefen()
            }
        }
    }

    /// Einstellungen an die Verbindung geben (Adresse/Token kurz verzögert – beim Tippen nicht bei jedem Zeichen)
    func uebernehmen(sofort: Bool = false) {
        ha.konto = einstellungen.konto
        verzoegert?.cancel()
        let verbinden = { [weak self] in
            guard let self else { return }
            self.ha.verbinde(adresse: self.einstellungen.adresse, token: self.einstellungen.token)
            self.widgetsAktualisieren(sofort: true)
        }
        if sofort {
            verbinden()
        } else {
            verzoegert = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                verbinden()
            }
        }
    }

    /// Regelmäßig neu laden – und kurz nach jedem Blick der Integration ins Postfach (2:00, 5:00 …)
    private func dauerlauf() async {
        var zuletzt = Date()
        while true {
            try? await Task.sleep(for: .seconds(30))
            let regel = Double(max(1, einstellungen.minuten)) * 60
            let abruf = ha.post?.naechsterAbruf.map { $0.addingTimeInterval(180) }
            let faellig = Date().timeIntervalSince(zuletzt) >= regel || (abruf.map { Date() >= $0 && zuletzt < $0 } ?? false)
            if faellig {
                zuletzt = Date()
                await ha.laden()
            }
        }
    }

    /// Datenpaket und kleine Umschlagbilder für die Widgets schreiben und sie neu laden lassen
    func widgetsAktualisieren(sofort: Bool = false) {
        let w = WidgetDaten(post: ha.gezeigt, eingerichtet: einstellungen.eingerichtet, fehler: ha.post == nil ? ha.fehler : "")
        var vergleich = w
        vergleich.stand = letzteWidgetDaten?.stand ?? w.stand
        guard sofort || vergleich != letzteWidgetDaten else { return }
        letzteWidgetDaten = w
        do {
            try w.schreiben()
            bilderSchreiben(w.offen + (w.zuletzt.map { [$0] } ?? []))
        } catch {
            NSLog("Widgets: \(error)")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Umschläge verkleinert als JPEG ablegen (die Widgets lesen nur diese Dateien)
    private func bilderSchreiben(_ briefe: [Brief]) {
        let ordner = WidgetDaten.ordner.appendingPathComponent("bilder", isDirectory: true)
        let ids = Set(briefe.map(\.id))
        for datei in (try? FileManager.default.contentsOfDirectory(atPath: ordner.path)) ?? [] where !ids.contains(String(datei.prefix(20))) {
            try? FileManager.default.removeItem(at: ordner.appendingPathComponent(datei))
        }
        for b in briefe {
            let ziel = ordner.appendingPathComponent("\(b.id).jpg")
            guard !FileManager.default.fileExists(atPath: ziel.path), let bild = ha.bilder[b.id] else { continue }
            let breite: CGFloat = 520
            let f = breite / max(1, bild.size.width)
            let groesse = NSSize(width: breite, height: max(1, bild.size.height * f))
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(groesse.width), pixelsHigh: Int(groesse.height), bitsPerSample: 8,
                                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
            else { continue }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor(red: 0.985, green: 0.976, blue: 0.953, alpha: 1).setFill()
            NSRect(origin: .zero, size: groesse).fill()
            bild.draw(in: NSRect(origin: .zero, size: groesse))
            NSGraphicsContext.restoreGraphicsState()
            try? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])?.write(to: ziel, options: .atomic)
        }
    }

    // MARK: Befehle der Widgets

    private func befehleEmpfangen() {
        DistributedNotificationCenter.default().addObserver(forName: .init(WidgetDaten.befehlsName), object: nil, queue: .main) { n in
            guard let text = n.object as? String else { return }
            MainActor.assumeIsolated { Kern.shared.ausfuehren(text) }
        }
    }

    func ausfuehren(_ befehl: String) {
        let teile = befehl.split(separator: "|").map(String.init)
        // Nur bekannte Briefe annehmen – die Mitteilungen kann jedes Programm auf dem Mac schicken
        guard teile.count == 2, teile[0] == "erledigt", ha.post?.briefe.contains(where: { $0.id == teile[1] }) == true else { return }
        ha.abhaken(teile[1], true)
    }
}

/// Panel mit Zugriff auf openWindow (für Einstellungen, Fenster, Was ist neu?)
struct PanelMitFenster: View {
    let kern: Kern
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        PanelAnsicht(kern: kern, oeffnen: oeffnen)
            .onAppear { kern.fensterOeffnen = oeffnen }
    }

    private func oeffnen(_ id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Symbol in der Menüleiste: Umschlag, daneben die Zahl der Sendungen unterwegs
struct MenueSymbol: View {
    let kern: Kern
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let g = kern.gruppen
        let symbol = !kern.einstellungen.eingerichtet || (kern.ha.post == nil && !kern.ha.fehler.isEmpty) ? "envelope.badge.shield.half.filled"
            : g.heute.isEmpty ? (g.offen.isEmpty ? "envelope" : "envelope.fill") : "envelope.badge.fill"
        Group {
            if kern.einstellungen.zeigeAnzahl && !g.offen.isEmpty {
                Label("\(g.offen.count)", systemImage: symbol)
                    .labelStyle(.titleAndIcon)
                    .monospacedDigit()
            } else {
                Image(systemName: symbol)
            }
        }
        .onAppear {
            kern.fensterOeffnen = { id in
                openWindow(id: id)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            if Kern.shared.vorschau { Vorschau.starten(Kern.shared) }
            // Noch nicht eingerichtet: gleich die Einstellungen zeigen
            else if !Kern.shared.einstellungen.eingerichtet && !CommandLine.arguments.contains("--nur-starten") {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    Kern.shared.fensterOeffnen("einstellungen")
                }
            }
        }
    }

    /// Klick auf das Pakete-Widget: Fenster mit den Paketen
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            if urls.contains(where: { $0.scheme == "briefankuendigung" && $0.host == "pakete" }) { Kern.shared.bereich = "pakete" }
            Kern.shared.fensterOeffnen("briefe")
        }
    }

    /// Klick auf ein Widget (App läuft schon): das Fenster mit allen Briefen zeigen
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { Kern.shared.fensterOeffnen("briefe") }
        return false
    }
}
