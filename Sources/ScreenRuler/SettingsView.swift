import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var onStartRuler: () -> Void = {}

    @AppStorage(Prefs.unitKey) private var unit: MeasureUnit = .pixels
    @AppStorage(Prefs.toleranceKey) private var tolerance: Double = 30
    @AppStorage(Prefs.perChannelKey) private var perChannel = false
    @AppStorage(Prefs.continuousKey) private var continuous = false
    @AppStorage(Prefs.lineColorKey) private var lineColorHex = "#FF4F00"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var lineColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: lineColorHex) ?? .systemOrange) },
            set: { lineColorHex = NSColor($0).hexString }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ScreenRuler toimii valikkorivillä.").font(.headline)
                    Text("Käynnistä viivain painamalla ⌘⇧M, valikkorivin viivainkuvakkeesta tai avaamalla sovellus uudelleen.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Käynnistä viivain nyt", action: onStartRuler)
                        .padding(.top, 4)
                }
            }

            Section("Yleiset") {
                LabeledContent("Pikanäppäin", value: "⌘ ⇧ M")
                Toggle("Käynnistä kirjautuessa", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            NSLog("ScreenRuler: launch at login failed: \(error)")
                        }
                    }
                LabeledContent("Näytön tallennuslupa") {
                    if ScreenCapture.hasPermission {
                        Text("Myönnetty").foregroundStyle(.secondary)
                    } else {
                        Button("Avaa Järjestelmäasetukset") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                        }
                    }
                }
                if !ScreenCapture.hasPermission {
                    Text("Ilman lupaa vain Rajat-tila toimii. Salli ScreenRuler kohdassa Näytön ja äänen tallennus ja käynnistä sovellus sen jälkeen uudelleen.")
                        .font(.callout).foregroundStyle(.orange)
                }
            }

            Section("Mittaus") {
                Picker("Yksikkö", selection: $unit) {
                    ForEach(MeasureUnit.allCases) { Text($0.title).tag($0) }
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text("Reunantunnistuksen toleranssi")
                        Spacer()
                        Text("\(Int(tolerance))").monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $tolerance, in: 0...255, step: 1)
                }
                Toggle("Tunnista reunat värikanavittain", isOn: $perChannel)
                Toggle("Jatkuva näytönkaappaus", isOn: $continuous)
                ColorPicker("Viivan väri", selection: lineColor, supportsOpacity: false)
            }

            Section("Käyttö") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⌘⇧M käynnistää / sulkee viivaimen, Esc sulkee.")
                    Text("1–4 vaihtaa tilaa: rajat, välit, vaaka, pysty.")
                    Text("Klikkaus kopioi mitan leikepöydälle. ⇧+klikkaus säilyttää mitan.")
                    Text("Nuolinäppäimet siirtävät osoitinta pikselin kerrallaan.")
                    Text("Oikea klikkaus tai ⌫ tyhjentää säilytetyt mitat.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
