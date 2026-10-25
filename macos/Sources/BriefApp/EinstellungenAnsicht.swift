import SwiftUI
import BriefLogik

/// Einstellungen: Home Assistant, Postfach, Anzeige, Start, Updates
struct EinstellungenAnsicht: View {
    let kern: Kern
    @State private var adresse = ""
    @State private var token = ""
    @State private var test: (ok: Bool, text: String)?
    @State private var testLaeuft = false
    @State private var konten: [String] = []
    @State private var anmeldeStart = false

    var body: some View {
        @Bindable var e = kern.einstellungen
        Form {
            Section {
                TextField(T("Adresse"), text: $adresse, prompt: Text("https://homeassistant.local:8123"))
                    .onSubmit(uebernehmen)
                SecureField(T("Token"), text: $token, prompt: Text(T("Langlebiges Zugriffstoken")))
                    .onSubmit(uebernehmen)
                HStack {
                    Button(T("Speichern und testen")) { uebernehmen() }
                        .glasKnopfBetont()
                        .disabled(testLaeuft)
                    if e.toolboxInstanz != nil {
                        Button(T("Aus Home Assistant ToolBox übernehmen")) {
                            if e.vonToolboxUebernehmen() { adresse = e.adresse; token = e.token; Task { await testen() } }
                        }
                        .glasKnopf()
                    }
                    if testLaeuft { ProgressView().controlSize(.small) }
                }
                if let test {
                    Label(test.text, systemImage: test.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(test.ok ? .green : .red)
                }
            } header: {
                Text(T("Home Assistant"))
            } footer: {
                Text(T("Token anlegen: in Home Assistant unten links auf den Namen → Sicherheit → „Langlebige Zugriffstoken“. Der Token liegt im Schlüsselbund."))
                    .foregroundStyle(.secondary)
            }

            Section(T("Anzeige")) {
                Picker(T("Postfach"), selection: $e.konto) {
                    Text(T("Alle Postfächer")).tag("")
                    ForEach(Array(Set(konten + [e.konto]).filter { !$0.isEmpty }).sorted(), id: \.self) { Text($0).tag($0) }
                }
                Picker(T("Im Menü"), selection: $e.modus) {
                    Text(T("Karten zum Durchblättern")).tag("karten")
                    Text(T("Liste")).tag("liste")
                }
                Toggle(T("Karten von selbst weiterblättern"), isOn: $e.automatisch)
                Toggle(T("Anzahl in der Menüleiste zeigen"), isOn: $e.zeigeAnzahl)
                Stepper(value: $e.minuten, in: 1...120) {
                    Text(T("Neu laden alle %1 min", "\(e.minuten)"))
                }
            }

            Section {
                Toggle(T("Beim Anmelden starten"), isOn: $anmeldeStart)
                    .onChange(of: anmeldeStart) { _, neu in kern.einstellungen.anmeldeStart = neu }
                Toggle(T("Automatisch nach neuen Versionen suchen"), isOn: $e.updatesSuchen)
                LabeledContent(T("Version"), value: kern.aktualisierer.aktuelleVersion)
                Link(T("Quelltext auf GitHub"), destination: URL(string: "https://github.com/Teyro/Briefankuendigung-Desktop")!)
            } header: {
                Text(T("Start und Updates"))
            } footer: {
                Text(T("Widgets: Rechtsklick auf den Schreibtisch → „Widgets bearbeiten …“ → Briefankündigung."))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 600)
        .onAppear {
            adresse = kern.einstellungen.adresse
            token = kern.einstellungen.token
            anmeldeStart = kern.einstellungen.anmeldeStart
            if kern.einstellungen.eingerichtet { Task { await testen() } }
        }
    }

    private func uebernehmen() {
        kern.einstellungen.adresse = PostText.adresse(adresse)
        kern.einstellungen.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        adresse = kern.einstellungen.adresse
        Task { await testen() }
    }

    private func testen() async {
        testLaeuft = true
        let r = await Verbindung.testen(adresse: adresse, token: token)
        testLaeuft = false
        test = (r.ok, r.text)
        konten = r.konten
    }
}
