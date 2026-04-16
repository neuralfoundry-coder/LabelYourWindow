import SwiftUI

@main
struct LabelYourWindowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("LabelYourWindow", systemImage: "tag.fill") {
            MenuBarView(appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: appDelegate.settings)
        }
    }
}
