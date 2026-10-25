import WidgetKit
import SwiftUI
import AppIntents
import BriefLogik

/// Widgets von Briefankündigung für den Schreibtisch und die Mitteilungszentrale.
@main
struct BriefWidgets: WidgetBundle {
    init() { Sprache.laden() }
    var body: some Widget {
        PostWidget()
    }
}

struct Eintrag: TimelineEntry {
    let date: Date
    let daten: WidgetDaten
    let index: Int
}

struct Anbieter: TimelineProvider {
    private func aktuell() -> Eintrag {
        let d = WidgetDaten.lesen() ?? WidgetDaten()
        let n = d.offen.count
        let i = n > 0 ? min(max(0, WidgetSpeicher.index), n - 1) : 0
        return Eintrag(date: Date(), daten: d, index: i)
    }
    func placeholder(in context: Context) -> Eintrag { aktuell() }
    func getSnapshot(in context: Context, completion: @escaping (Eintrag) -> Void) { completion(aktuell()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Eintrag>) -> Void) {
        // Die App stößt bei Änderungen an; sonst alle 15 Minuten (für „heute“ und „vor 3 h“)
        completion(Timeline(entries: [aktuell()], policy: .after(Date().addingTimeInterval(900))))
    }
}

struct PostWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "post", provider: Anbieter()) { e in
            WidgetInhalt(e: e)
        }
        .configurationDisplayName(T("Briefankündigung"))
        .description(T("Angekündigte Briefe und Pakete – zum Durchblättern oder als Liste."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetInhalt: View {
    let e: Eintrag
    @Environment(\.widgetFamily) private var familie
    var body: some View {
        Group {
            switch familie {
            case .systemSmall: KleinesWidget(daten: e.daten)
            case .systemLarge, .systemExtraLarge: ListenWidget(daten: e.daten)
            default: KartenWidget(daten: e.daten, index: e.index)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color.accentColor.opacity(0.14), Color.accentColor.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .background(.background)
        }
    }
}
