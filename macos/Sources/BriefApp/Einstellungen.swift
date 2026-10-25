import Foundation
import Observation
import Security
import ServiceManagement
import BriefLogik

/// Einstellungen der App: alles in den Benutzereinstellungen, der Token im Schlüsselbund.
@MainActor
@Observable
final class Einstellungen {
    @ObservationIgnored private let d = UserDefaults.standard
    @ObservationIgnored var geaendert: () -> Void = {}
    @ObservationIgnored let vorschau: Bool

    var adresse: String { didSet { d.set(adresse, forKey: "adresse"); geaendert() } }
    var konto: String { didSet { d.set(konto, forKey: "konto"); geaendert() } }
    var minuten: Int { didSet { d.set(minuten, forKey: "minuten"); geaendert() } }
    /// Panel: "karten" oder "liste"
    var modus: String { didSet { d.set(modus, forKey: "modus") } }
    var automatisch: Bool { didSet { d.set(automatisch, forKey: "automatisch") } }
    var zeigeAnzahl: Bool { didSet { d.set(zeigeAnzahl, forKey: "zeigeAnzahl") } }
    var updatesSuchen: Bool { didSet { d.set(updatesSuchen, forKey: "updatesSuchen") } }
    /// Token (im Schlüsselbund; im Testlauf nur im Speicher)
    var token: String {
        didSet {
            if !vorschau { Schluesselbund.speichern(token, konto: "token") }
            geaendert()
        }
    }

    init(vorschau: Bool = false) {
        self.vorschau = vorschau
        d.register(defaults: ["minuten": 10, "modus": "karten", "automatisch": true, "zeigeAnzahl": true, "updatesSuchen": true])
        adresse = vorschau ? "" : d.string(forKey: "adresse") ?? ""
        konto = vorschau ? "" : d.string(forKey: "konto") ?? ""
        minuten = max(1, d.integer(forKey: "minuten"))
        modus = d.string(forKey: "modus") ?? "karten"
        automatisch = d.bool(forKey: "automatisch")
        zeigeAnzahl = d.bool(forKey: "zeigeAnzahl")
        updatesSuchen = d.bool(forKey: "updatesSuchen")
        token = vorschau ? "" : (Schluesselbund.lesen(konto: "token") ?? "")
    }

    var eingerichtet: Bool { !adresse.isEmpty && !token.isEmpty }

    // MARK: Zugang aus Home Assistant ToolBox übernehmen (gleicher Mac)

    /// Favorit (oder erste Instanz) der ToolBox – ohne Token, der kommt erst beim Übernehmen aus dem Schlüsselbund
    var toolboxInstanz: (id: String, adresse: String, name: String)? {
        guard let tb = UserDefaults(suiteName: "de.teyro.homeassistanttoolbox"), let j = tb.data(forKey: "instanzen"),
              let liste = try? JSONSerialization.jsonObject(with: j) as? [[String: Any]] else { return nil }
        let mitAdresse = liste.filter { !(($0["adresse"] as? String) ?? "").isEmpty }
        guard let i = mitAdresse.first(where: { ($0["favorit"] as? Bool) == true }) ?? mitAdresse.first,
              let id = i["id"] as? String, let a = i["adresse"] as? String else { return nil }
        return (id, a, i["name"] as? String ?? "")
    }

    /// macOS fragt dabei einmal, ob die App den Eintrag der ToolBox lesen darf
    func vonToolboxUebernehmen() -> Bool {
        guard let i = toolboxInstanz,
              let t = Schluesselbund.lesen(konto: "token-" + i.id, dienst: "de.teyro.homeassistanttoolbox"), !t.isEmpty else { return false }
        adresse = PostText.adresse(i.adresse)
        token = t
        return true
    }

    /// Beim Anmelden automatisch starten
    var anmeldeStart: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Anmeldeobjekt: \(error)")
            }
        }
    }
}

/// Token im Schlüsselbund von macOS (nicht als Klartext in den Einstellungen).
enum Schluesselbund {
    static let dienst = "de.teyro.briefankuendigung"

    static func basis(_ konto: String, dienst: String = Schluesselbund.dienst) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: dienst, kSecAttrAccount as String: konto]
    }

    static func lesen(konto: String, dienst: String = Schluesselbund.dienst) -> String? {
        var q = basis(konto, dienst: dienst)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var ergebnis: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &ergebnis) == errSecSuccess, let d = ergebnis as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func speichern(_ token: String, konto: String) {
        if token.isEmpty {
            SecItemDelete(basis(konto) as CFDictionary)
            return
        }
        let daten = Data(token.utf8)
        let status = SecItemUpdate(basis(konto) as CFDictionary, [kSecValueData as String: daten] as CFDictionary)
        if status == errSecItemNotFound {
            var neu = basis(konto)
            neu[kSecValueData as String] = daten
            neu[kSecAttrLabel as String] = T("Briefankündigung – Home Assistant Token")
            SecItemAdd(neu as CFDictionary, nil)
        }
    }
}
