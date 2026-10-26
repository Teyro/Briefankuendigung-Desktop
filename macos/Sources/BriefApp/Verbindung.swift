import Foundation
import AppKit
import Observation
import BriefLogik

/// Verbindung zu Home Assistant: Briefe und Pakete der Integration „Briefankündigung“, Umschlagbilder,
/// „Angekommen“ und „Jetzt nachsehen“.
@MainActor
@Observable
final class Verbindung {
    private(set) var post: Post?
    private(set) var bilder: [String: NSImage] = [:]
    private(set) var laedt = false
    private(set) var nachsehen = false
    private(set) var fehler = ""
    private(set) var fehltIntegration = false
    /// Token abgelehnt: nicht weiter fragen (Home Assistant sperrt sonst die IP-Adresse)
    private(set) var abgelehnt = false
    var meldung = ""

    @ObservationIgnored private var basis = ""
    @ObservationIgnored private var token = ""
    @ObservationIgnored var konto = ""
    @ObservationIgnored var nachLaden: () -> Void = {}

    var eingerichtet: Bool { !basis.isEmpty && !token.isEmpty }
    var adresse: String { basis }
    /// Gezeigte Briefe (gewähltes Postfach)
    var gezeigt: Post? { post?.nur(konto: konto) }

    func verbinde(adresse: String, token: String) {
        let a = PostText.adresse(adresse), t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard a != basis || t != self.token else { return }
        if a != basis { post = nil; bilder = [:] }
        basis = a
        self.token = t
        abgelehnt = false
        fehler = ""
        Task { await laden() }
    }

    private func anfrage(_ pfad: String, methode: String = "GET", koerper: [String: Any]? = nil) async -> (Data?, Int) {
        guard eingerichtet, let url = URL(string: basis + pfad) else { return (nil, -1) }
        var r = URLRequest(url: url)
        r.httpMethod = methode
        r.timeoutInterval = 20
        r.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let koerper { r.httpBody = try? JSONSerialization.data(withJSONObject: koerper) }
        guard let (d, a) = try? await URLSession.shared.data(for: r) else { return (nil, 0) }
        return (d, (a as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private func fehlerText(_ status: Int) -> String {
        switch status {
        case 401, 403: T("Zugriff verweigert – bitte den Token prüfen.")
        case 404: T("Die Integration „Briefankündigung“ fehlt in Home Assistant (HACS).")
        case 0: T("Home Assistant ist nicht erreichbar (%1).", basis)
        default: T("Fehler %1 von Home Assistant.", "\(status)")
        }
    }

    func laden() async {
        guard eingerichtet, !abgelehnt else { return }
        laedt = true
        defer { laedt = false }
        let (d, status) = await anfrage("/api/briefankuendigung/briefe")
        if status == 401 || status == 403 { abgelehnt = true }
        fehltIntegration = status == 404
        guard status == 200, let d, let j = JSON.lesen(d), let p = Post.aus(j) else {
            fehler = status == 200 ? T("Unerwartete Antwort von Home Assistant.") : fehlerText(status)
            nachLaden()
            return
        }
        fehler = ""
        post = p
        if nachsehen && !p.laeuft, let s = p.stand, s > nachsehenSeit { nachsehen = false }
        await bilderLaden(p)
        nachLaden()
    }

    /// Umschlagbilder (nur fehlende; alte fallen weg)
    private func bilderLaden(_ p: Post) async {
        let ids = Set(p.briefe.map(\.id))
        bilder = bilder.filter { ids.contains($0.key) }
        for b in p.briefe.prefix(30) where b.bild && bilder[b.id] == nil {
            let (d, status) = await anfrage("/api/briefankuendigung/bild/" + b.id)
            if status == 200, let d, let i = NSImage(data: d) { bilder[b.id] = i }
        }
    }

    /// „Angekommen“ (gilt auf allen Geräten) – sofort anzeigen, dann speichern
    func abhaken(_ id: String, _ erledigt: Bool) {
        if var p = post, let i = p.briefe.firstIndex(where: { $0.id == id }) {
            p.briefe[i].erledigt = erledigt
            post = p
            nachLaden()
        }
        Task {
            let (_, status) = await anfrage("/api/briefankuendigung/erledigt", methode: "POST", koerper: ["id": id, "erledigt": erledigt])
            if status != 200 { meldung = fehlerText(status); await laden() }
        }
    }

    /// Sendung von Hand verfolgen – gibt bei Erfolg "" zurück, sonst den Fehler
    func sendungHinzufuegen(nummer: String, dienst: String, name: String) async -> String {
        let (_, status) = await anfrage("/api/briefankuendigung/sendung", methode: "POST",
                                        koerper: ["nummer": nummer, "dienst": dienst, "name": name, "konto": konto])
        switch status {
        case 200: await laden(); return ""
        case 400: return T("Sendungsnummer oder Paketdienst nicht erkannt.")
        case 404, 405: return T("Dafür die Integration auf Version 1.4 aktualisieren.")
        default: return fehlerText(status)
        }
    }

    /// Von Hand hinzugefügte Sendung entfernen (Sendungen aus Mails gelten danach als angekommen)
    func sendungEntfernen(_ id: String) {
        if var p = post {
            p.briefe.removeAll { $0.id == id && $0.manuell }
            post = p
            nachLaden()
        }
        Task {
            let (_, status) = await anfrage("/api/briefankuendigung/sendung/entfernen", methode: "POST", koerper: ["id": id])
            if status != 200 { meldung = fehlerText(status) }
            await laden()
        }
    }

    @ObservationIgnored private var nachsehenSeit = Date.distantPast
    /// Home Assistant jetzt ins Postfach schauen lassen und ein paar Mal nachladen
    func jetztNachsehen() {
        guard !nachsehen else { return }
        nachsehen = true
        nachsehenSeit = post?.stand ?? .distantPast
        Task {
            let k = konto.isEmpty ? "" : "?konto=" + (konto.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            let (_, status) = await anfrage("/api/briefankuendigung/abrufen" + k, methode: "POST", koerper: [:])
            guard status == 200 || status == 202 else { nachsehen = false; meldung = fehlerText(status); return }
            for _ in 0..<8 where nachsehen {
                try? await Task.sleep(for: .seconds(5))
                await laden()
            }
            nachsehen = false
        }
    }

    func erneutVersuchen() {
        abgelehnt = false
        Task { await laden() }
    }

    /// Verbindung prüfen (Einstellungen): Text und Postfächer
    static func testen(adresse: String, token: String) async -> (ok: Bool, text: String, konten: [String]) {
        let a = PostText.adresse(adresse)
        guard let url = URL(string: a + "/api/briefankuendigung/briefe"), !token.isEmpty else { return (false, T("Bitte Adresse und Token eintragen."), []) }
        var r = URLRequest(url: url)
        r.timeoutInterval = 15
        r.setValue("Bearer " + token.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "Authorization")
        guard let (d, antwort) = try? await URLSession.shared.data(for: r) else { return (false, T("Home Assistant ist nicht erreichbar (%1).", a), []) }
        let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            guard let j = JSON.lesen(d), let p = Post.aus(j) else { return (false, T("Unerwartete Antwort von Home Assistant."), []) }
            let offen = p.briefe.filter { !$0.istErledigt }.count
            return (true, T("Verbunden – %1 Postfächer, %2 Sendungen unterwegs.", "\(p.konten.count)", "\(offen)"), p.konten.map(\.name))
        case 401, 403: return (false, T("Zugriff verweigert – bitte den Token prüfen."), [])
        case 404: return (false, T("Die Integration „Briefankündigung“ fehlt in Home Assistant (HACS)."), [])
        default: return (false, T("Fehler %1 von Home Assistant.", "\(status)"), [])
        }
    }
}
