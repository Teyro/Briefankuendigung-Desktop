import Foundation

/// Alles, was die Widgets zeigen. Die App schreibt es als JSON-Datei (dazu kleine Umschlagbilder),
/// die Widgets lesen es nur – sie haben keinen Zugang zu Home Assistant.
public struct WidgetDaten: Codable, Equatable, Sendable {
    public var stand: Date = .distantPast
    public var gelesen: Date?
    public var naechsterAbruf: Date?
    public var eingerichtet = false
    public var fehler = ""
    public var offen: [Brief] = []
    public var heute = 0
    public var zuletzt: Brief?
    public var mehrereKonten = false

    public init() {}

    public init(post: Post?, eingerichtet: Bool, fehler: String, jetzt: Date = Date()) {
        self.eingerichtet = eingerichtet
        self.fehler = fehler
        stand = jetzt
        guard let post else { return }
        let g = Gruppen(post.briefe, jetzt: jetzt)
        offen = Array(g.offen.prefix(12))
        heute = g.heute.count
        zuletzt = g.angekommen.first
        gelesen = post.stand
        naechsterAbruf = post.naechsterAbruf
        mehrereKonten = post.mehrereKonten
    }

    /// Ordner der App (die Widgets lesen ihn über eine Ausnahme in ihrer Sandbox)
    public static var ordner: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Briefankuendigung", isDirectory: true)
    }
    /// In der Sandbox der Widgets zeigt homeDirectoryForCurrentUser in den Container – dort den echten Pfad nehmen
    public static var echterOrdner: URL {
        URL(fileURLWithPath: "/Users/\(NSUserName())/Library/Application Support/Briefankuendigung", isDirectory: true)
    }
    public static var datei: URL { ordner.appendingPathComponent("widgets.json") }

    /// Kleines Umschlagbild für die Widgets (JPEG)
    public static func bild(_ id: String) -> URL? {
        for o in [echterOrdner, ordner] {
            let u = o.appendingPathComponent("bilder/\(id).jpg")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    public static func lesen() -> WidgetDaten? {
        for o in [echterOrdner, ordner] {
            if let d = try? Data(contentsOf: o.appendingPathComponent("widgets.json")) {
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .secondsSince1970
                if let w = try? dec.decode(WidgetDaten.self, from: d) { return w }
            }
        }
        return nil
    }

    public func schreiben() throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        try FileManager.default.createDirectory(at: Self.ordner.appendingPathComponent("bilder"), withIntermediateDirectories: true)
        try enc.encode(self).write(to: Self.datei, options: .atomic)
    }

    // MARK: Befehle der Widgets an die App (verteilte Mitteilung, ohne Token im Widget)

    public static let befehlsName = "de.teyro.briefankuendigung.befehl"
    /// "erledigt|<id>"
    public static func befehl(_ teile: String...) -> String { teile.joined(separator: "|") }
}
