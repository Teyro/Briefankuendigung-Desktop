import Foundation

/// Ein angekündigter Brief oder ein DHL-Paket (aus der Integration „Briefankündigung“ in Home Assistant).
public struct Brief: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String
    public var datum: Date
    public var absender: String
    public var paket: Bool
    public var bild: Bool
    public var wichtig: Bool
    public var erledigt: Bool
    public var sendung: String
    /// "unterwegs" | "heute" | "zugestellt" (nur Pakete)
    public var stand: String
    public var kontoId: String
    public var kontoName: String

    public init(id: String, datum: Date, absender: String, paket: Bool = false, bild: Bool = false, wichtig: Bool = false,
                erledigt: Bool = false, sendung: String = "", stand: String = "", kontoId: String = "", kontoName: String = "") {
        self.id = id; self.datum = datum; self.absender = absender; self.paket = paket; self.bild = bild; self.wichtig = wichtig
        self.erledigt = erledigt; self.sendung = sendung; self.stand = stand; self.kontoId = kontoId; self.kontoName = kontoName
    }

    /// Angekommen: abgehakt oder zugestelltes Paket
    public var istErledigt: Bool { erledigt || (paket && stand == "zugestellt") }
    /// Paket: 1 unterwegs, 2 kommt heute, 3 zugestellt
    public var stufe: Int { stand == "zugestellt" ? 3 : stand == "heute" ? 2 : 1 }
    public var absenderText: String { absender.isEmpty ? (paket ? T("Paket") : T("Absender unbekannt")) : absender }
}

/// Ein Postfach (Konto) der Integration
public struct Konto: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var stand: Date?
    public var fehler: String
    public var naechsterAbruf: Date?
    public var laeuft: Bool
    public init(id: String, name: String, stand: Date? = nil, fehler: String = "", naechsterAbruf: Date? = nil, laeuft: Bool = false) {
        self.id = id; self.name = name; self.stand = stand; self.fehler = fehler; self.naechsterAbruf = naechsterAbruf; self.laeuft = laeuft
    }
}

/// Antwort von GET /api/briefankuendigung/briefe
public struct Post: Equatable, Sendable {
    public var stand: Date?
    public var fehler: String
    public var konten: [Konto]
    public var briefe: [Brief]
    public init(stand: Date? = nil, fehler: String = "", konten: [Konto] = [], briefe: [Brief] = []) {
        self.stand = stand; self.fehler = fehler; self.konten = konten; self.briefe = briefe
    }

    /// Aus der Antwort der Integration lesen; nil, wenn es keine Brief-Liste ist
    public static func aus(_ j: JSON) -> Post? {
        guard let liste = j["briefe"]?.liste else { return nil }
        func zeit(_ x: JSON?) -> Date? { x?.zahl.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0 / 1000) : nil } }
        let konten = (j["konten"]?.liste ?? []).map { k in
            Konto(id: k["id"]?.text ?? "", name: k["name"]?.text ?? "", stand: zeit(k["stand"]), fehler: k["fehler"]?.text ?? "",
                  naechsterAbruf: zeit(k["naechster_abruf"]), laeuft: k["laeuft"]?.bool ?? false)
        }
        let briefe = liste.compactMap { b -> Brief? in
            guard let id = b["id"]?.text, let d = zeit(b["datum"]) else { return nil }
            return Brief(id: id, datum: d, absender: b["absender"]?.text ?? "", paket: b["art"]?.text == "paket",
                         bild: b["bild"]?.bool ?? false, wichtig: b["wichtig"]?.bool ?? false, erledigt: b["erledigt"]?.bool ?? false,
                         sendung: b["sendung"]?.text ?? "", stand: b["stand"]?.text ?? "",
                         kontoId: b["konto"]?.text ?? "", kontoName: b["konto_name"]?.text ?? "")
        }
        return Post(stand: zeit(j["stand"]), fehler: j["fehler"]?.text ?? "", konten: konten, briefe: briefe)
    }

    /// Nur ein Postfach (Name oder ID, ohne Groß/klein); "" = alle
    public func nur(konto: String) -> Post {
        let k = konto.trimmingCharacters(in: .whitespaces).lowercased()
        guard !k.isEmpty else { return self }
        var p = self
        p.briefe = briefe.filter { $0.kontoId.lowercased() == k || $0.kontoName.lowercased() == k }
        p.konten = konten.filter { $0.id.lowercased() == k || $0.name.lowercased() == k }
        return p
    }

    /// Frühester nächster Abruf der Integration
    public var naechsterAbruf: Date? { konten.compactMap(\.naechsterAbruf).min() }
    public var laeuft: Bool { konten.contains { $0.laeuft } }
    public var mehrereKonten: Bool { Set(briefe.map(\.kontoId)).count > 1 }
}

/// Briefe gruppiert: heute angekündigt / noch unterwegs / angekommen
public struct Gruppen: Equatable, Sendable {
    public var heute: [Brief] = []
    public var unterwegs: [Brief] = []
    public var angekommen: [Brief] = []
    public var offen: [Brief] { heute + unterwegs }

    public init(_ briefe: [Brief], jetzt: Date = Date(), kalender: Calendar = .current) {
        // wichtige zuerst, sonst neueste zuerst
        let sortiert = briefe.sorted { ($0.wichtig ? 1 : 0, $0.datum) > ($1.wichtig ? 1 : 0, $1.datum) }
        for b in sortiert {
            if b.istErledigt { angekommen.append(b) }
            else if kalender.isDate(b.datum, inSameDayAs: jetzt) { heute.append(b) }
            else { unterwegs.append(b) }
        }
        angekommen.sort { $0.datum > $1.datum }
    }
}

public enum PostText {
    /// "2 Briefe, 1 Paket"
    public static func anzahl(_ liste: [Brief]) -> String {
        let p = liste.filter(\.paket).count, b = liste.count - p
        var teile: [String] = []
        if b > 0 { teile.append(b == 1 ? T("1 Brief") : T("%1 Briefe", "\(b)")) }
        if p > 0 { teile.append(p == 1 ? T("1 Paket") : T("%1 Pakete", "\(p)")) }
        return teile.joined(separator: ", ")
    }

    /// "3 Briefe unterwegs" bzw. "Nichts unterwegs"
    public static func titel(_ offen: [Brief]) -> String {
        offen.isEmpty ? T("Nichts unterwegs") : T("%1 unterwegs", anzahl(offen))
    }

    /// "heute", "gestern", "Mo 19.10.", "12.10."
    public static func datum(_ d: Date, jetzt: Date = Date(), kalender: Calendar = .current) -> String {
        let tage = kalender.dateComponents([.day], from: kalender.startOfDay(for: d), to: kalender.startOfDay(for: jetzt)).day ?? 0
        if tage == 0 { return T("heute") }
        if tage == 1 { return T("gestern") }
        let wt = [T("So"), T("Mo"), T("Di"), T("Mi"), T("Do"), T("Fr"), T("Sa")][kalender.component(.weekday, from: d) - 1]
        let tm = "\(kalender.component(.day, from: d)).\(kalender.component(.month, from: d))."
        return tage > 1 && tage < 7 ? wt + " " + tm : tm
    }

    /// "angekündigt heute", "kommt heute", "zugestellt" (+ Postfach)
    public static func unterzeile(_ b: Brief, jetzt: Date = Date(), mitKonto: Bool = false, kalender: Calendar = .current) -> String {
        var teile: [String] = []
        if b.paket && b.stand == "zugestellt" { teile.append(T("zugestellt")) }
        else if b.paket && b.stand == "heute" { teile.append(T("kommt heute")) }
        else { teile.append(T("angekündigt %1", datum(b.datum, jetzt: jetzt, kalender: kalender))) }
        if b.erledigt && !b.paket { teile.append(T("angekommen")) }
        if mitKonto && !b.kontoName.isEmpty { teile.append(b.kontoName) }
        return teile.joined(separator: " · ")
    }

    /// "vor 5 min", "vor 3 h"
    public static func vor(_ d: Date?, jetzt: Date = Date()) -> String {
        guard let d else { return "" }
        let min = max(0, Int((jetzt.timeIntervalSince(d) / 60).rounded()))
        if min < 1 { return T("gerade eben") }
        if min < 60 { return T("vor %1 min", "\(min)") }
        let h = min / 60
        return h < 24 ? T("vor %1 h", "\(h)") : T("vor %1 d", "\(h / 24)")
    }

    /// DHL-Sendungsverfolgung
    public static func dhl(_ nummer: String) -> URL? {
        var k = URLComponents(string: "https://www.dhl.de/de/privatkunden/pakete-empfangen/verfolgen.html")
        k?.queryItems = [URLQueryItem(name: "piececode", value: nummer)]
        return k?.url
    }

    /// Adresse aufräumen: ohne Schrägstrich am Ende; ohne http(s):// → https://
    public static func adresse(_ s: String) -> String {
        var a = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while a.hasSuffix("/") { a.removeLast() }
        if !a.isEmpty && !a.lowercased().hasPrefix("http://") && !a.lowercased().hasPrefix("https://") { a = "https://" + a }
        return a
    }

    /// Index beim Durchblättern (läuft im Kreis)
    public static func blaettern(_ index: Int, _ schritt: Int, _ anzahl: Int) -> Int {
        anzahl > 0 ? ((index + schritt) % anzahl + anzahl) % anzahl : 0
    }

    /// "1.2.0" > "1.1.9"?
    public static func versionNeuer(_ a: String, _ b: String) -> Bool {
        func teile(_ s: String) -> [Int] {
            s.replacingOccurrences(of: "v", with: "", options: .anchored).split(whereSeparator: { $0 == "." || $0 == "-" }).map { Int($0) ?? 0 }
        }
        let x = teile(a), y = teile(b)
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}
