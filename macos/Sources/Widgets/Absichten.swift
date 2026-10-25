import AppIntents
import Foundation
import WidgetKit
import BriefLogik

// Aktionen in den Widgets. Blättern merkt sich das Widget selbst; „Angekommen“ schickt es der
// laufenden App (die Widgets haben keinen Token), die App speichert und schreibt den neuen Stand.

enum WidgetSpeicher {
    static let schluessel = "karte"
    static var index: Int {
        get { UserDefaults.standard.integer(forKey: schluessel) }
        set { UserDefaults.standard.set(newValue, forKey: schluessel) }
    }
}

/// Zum nächsten bzw. vorigen Brief blättern
struct BlaetternAbsicht: AppIntent {
    static var title: LocalizedStringResource = "Blättern"
    static var isDiscoverable = false

    @Parameter(title: "Schritt") var schritt: Int

    init() {}
    init(_ schritt: Int) { self.schritt = schritt }

    func perform() async throws -> some IntentResult {
        let n = WidgetDaten.lesen()?.offen.count ?? 0
        WidgetSpeicher.index = PostText.blaettern(WidgetSpeicher.index, schritt, n)
        return .result()
    }
}

/// Brief als angekommen markieren
struct AngekommenAbsicht: AppIntent {
    static var title: LocalizedStringResource = "Angekommen"
    static var isDiscoverable = false

    @Parameter(title: "Brief") var brief: String

    init() {}
    init(_ brief: String) { self.brief = brief }

    func perform() async throws -> some IntentResult {
        DistributedNotificationCenter.default().postNotificationName(.init(WidgetDaten.befehlsName), object: WidgetDaten.befehl("erledigt", brief),
                                                                     userInfo: nil, deliverImmediately: true)
        // der App kurz Zeit geben, den neuen Stand zu schreiben – danach lädt WidgetKit neu
        try? await Task.sleep(for: .seconds(1.5))
        return .result()
    }
}
