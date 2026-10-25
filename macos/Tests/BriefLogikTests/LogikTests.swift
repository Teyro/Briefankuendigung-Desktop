import XCTest
@testable import BriefLogik

final class LogikTests: XCTestCase {
    let kal: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return k
    }()
    lazy var jetzt = kal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 9))!

    func ms(_ d: Date) -> JSON { .zahl(d.timeIntervalSince1970 * 1000) }

    func beispiel() -> Post {
        let j: JSON = [
            "version": 2, "stand": ms(jetzt.addingTimeInterval(-7200)), "fehler": "",
            "konten": [["id": "e1", "name": "Christian", "naechster_abruf": ms(jetzt.addingTimeInterval(3600)), "laeuft": false],
                       ["id": "e2", "name": "Johanna", "naechster_abruf": ms(jetzt.addingTimeInterval(1800)), "laeuft": false]],
            "briefe": [
                ["id": "a", "datum": ms(jetzt.addingTimeInterval(-3600)), "absender": "AOK", "art": "brief", "bild": true, "konto": "e1", "konto_name": "Christian"],
                ["id": "b", "datum": ms(jetzt.addingTimeInterval(-7200)), "absender": "Finanzamt", "art": "brief", "wichtig": true, "konto": "e1", "konto_name": "Christian"],
                ["id": "c", "datum": ms(jetzt.addingTimeInterval(-86400)), "absender": "Thalia", "art": "paket", "stand": "heute", "sendung": "0034", "konto": "e1", "konto_name": "Christian"],
                ["id": "d", "datum": ms(jetzt.addingTimeInterval(-2 * 86400)), "absender": "Zalando", "art": "paket", "stand": "zugestellt", "konto": "e2", "konto_name": "Johanna"],
                ["id": "e", "datum": ms(jetzt.addingTimeInterval(-3 * 86400)), "absender": "", "art": "brief", "erledigt": true, "konto": "e2", "konto_name": "Johanna"],
                ["kaputt": true],
            ],
        ]
        return Post.aus(j)!
    }

    func testLesenUndGruppen() {
        let p = beispiel()
        XCTAssertEqual(p.briefe.count, 5)
        XCTAssertEqual(p.konten.map(\.name), ["Christian", "Johanna"])
        XCTAssertEqual(p.naechsterAbruf, jetzt.addingTimeInterval(1800))
        XCTAssertTrue(p.mehrereKonten)
        let g = Gruppen(p.briefe, jetzt: jetzt, kalender: kal)
        XCTAssertEqual(g.heute.map(\.id), ["b", "a"], "wichtige zuerst")
        XCTAssertEqual(g.unterwegs.map(\.id), ["c"])
        XCTAssertEqual(g.angekommen.map(\.id), ["d", "e"])
        XCTAssertEqual(PostText.titel(g.offen), "2 Briefe, 1 Paket unterwegs")
        XCTAssertEqual(PostText.titel([]), "Nichts unterwegs")
        XCTAssertNil(Post.aus(["nichts": 1]))
    }

    func testKontoUndTexte() {
        let p = beispiel()
        XCTAssertEqual(p.nur(konto: "johanna").briefe.map(\.id), ["d", "e"])
        XCTAssertEqual(p.nur(konto: "E1").briefe.count, 3)
        XCTAssertEqual(p.nur(konto: "").briefe.count, 5)
        let c = p.briefe.first { $0.id == "c" }!
        XCTAssertEqual(c.stufe, 2)
        XCTAssertEqual(PostText.unterzeile(c, jetzt: jetzt, mitKonto: true, kalender: kal), "kommt heute · Christian")
        let e = p.briefe.first { $0.id == "e" }!
        XCTAssertEqual(e.absenderText, "Absender unbekannt")
        XCTAssertEqual(PostText.unterzeile(e, jetzt: jetzt, kalender: kal), "angekündigt So 18.10. · angekommen")
        XCTAssertEqual(PostText.datum(jetzt.addingTimeInterval(-86400), jetzt: jetzt, kalender: kal), "gestern")
        XCTAssertEqual(PostText.datum(jetzt.addingTimeInterval(-9 * 86400), jetzt: jetzt, kalender: kal), "12.10.")
        XCTAssertEqual(PostText.vor(jetzt.addingTimeInterval(-3 * 3600 - 60), jetzt: jetzt), "vor 3 h")
        XCTAssertEqual(PostText.dhl("0034")?.absoluteString, "https://www.dhl.de/de/privatkunden/pakete-empfangen/verfolgen.html?piececode=0034")
        XCTAssertEqual(PostText.adresse(" homeassistant.local:8123/ "), "https://homeassistant.local:8123")
        XCTAssertEqual(PostText.blaettern(0, -1, 3), 2)
        XCTAssertEqual(PostText.blaettern(2, 1, 3), 0)
        XCTAssertTrue(PostText.versionNeuer("v1.10.0", "1.9.3"))
        XCTAssertFalse(PostText.versionNeuer("1.0.0", "1.0"))
    }

    func testWidgetDaten() throws {
        let w = WidgetDaten(post: beispiel(), eingerichtet: true, fehler: "", jetzt: Date())
        XCTAssertEqual(w.offen.count + (w.zuletzt == nil ? 0 : 1) >= 3, true)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        // über JSON hin und zurück (Datumswerte als Sekunden: Vergleich der Kodierung statt Gleitkomma)
        let einmal = try enc.encode(w)
        XCTAssertEqual(try enc.encode(dec.decode(WidgetDaten.self, from: einmal)), einmal)
        XCTAssertEqual(try dec.decode(WidgetDaten.self, from: einmal).offen.map(\.id), w.offen.map(\.id))
    }
}
