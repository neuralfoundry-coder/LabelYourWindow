import SwiftUI

struct SettingsView: View {
    let settings: SettingsManager

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem { Label("General", systemImage: "gear") }
            AppearanceSettingsView(settings: settings)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            RulesSettingsView(settings: settings)
                .tabItem { Label("Rules", systemImage: "list.bullet") }
        }
        .frame(width: 520, height: 420)
    }
}
