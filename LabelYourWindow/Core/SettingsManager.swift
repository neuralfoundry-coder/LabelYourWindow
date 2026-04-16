import SwiftUI
import ServiceManagement

enum DisplayMode: String, Codable, CaseIterable {
    case fadeAway = "Fade Away"
    case pinned = "Pinned"
}

enum LabelPosition: String, Codable, CaseIterable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case topCenter = "Top Center"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    case center = "Center"

    var displayName: String { rawValue }
}

@Observable
final class SettingsManager {
    // MARK: - Display

    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: UserDefaults.standard.string(forKey: "displayMode") ?? "Fade Away") ?? .fadeAway }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "displayMode") }
    }

    var fadeDuration: Double {
        get { stored("fadeDuration", default: 2.0) }
        set { UserDefaults.standard.set(newValue, forKey: "fadeDuration") }
    }

    var fadeAnimationDuration: Double {
        get { stored("fadeAnimationDuration", default: 0.5) }
        set { UserDefaults.standard.set(newValue, forKey: "fadeAnimationDuration") }
    }

    var labelPosition: LabelPosition {
        get { LabelPosition(rawValue: UserDefaults.standard.string(forKey: "labelPosition") ?? "Top Right") ?? .topRight }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "labelPosition") }
    }

    // MARK: - Appearance

    var fontSize: Double {
        get { stored("fontSize", default: 14.0) }
        set { UserDefaults.standard.set(newValue, forKey: "fontSize") }
    }

    var fontWeight: Int {
        get { Int(stored("fontWeight", default: 5.0)) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "fontWeight") }
    }

    var backgroundOpacity: Double {
        get { stored("backgroundOpacity", default: 0.6) }
        set { UserDefaults.standard.set(newValue, forKey: "backgroundOpacity") }
    }

    var cornerRadius: Double {
        get { stored("cornerRadius", default: 8.0) }
        set { UserDefaults.standard.set(newValue, forKey: "cornerRadius") }
    }

    var useGlassEffect: Bool {
        get { UserDefaults.standard.object(forKey: "useGlassEffect") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "useGlassEffect") }
    }

    var labelInset: Double {
        get { stored("labelInset", default: 12.0) }
        set { UserDefaults.standard.set(newValue, forKey: "labelInset") }
    }

    // MARK: - Behavior

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "isEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "isEnabled") }
    }

    var showOnWindowSwitch: Bool {
        get { UserDefaults.standard.object(forKey: "showOnWindowSwitch") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showOnWindowSwitch") }
    }

    var showOnAppSwitch: Bool {
        get { UserDefaults.standard.object(forKey: "showOnAppSwitch") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showOnAppSwitch") }
    }

    var allowDragging: Bool {
        get { UserDefaults.standard.object(forKey: "allowDragging") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "allowDragging") }
    }

    var launchAtLogin: Bool {
        get { UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
            updateLaunchAtLogin(newValue)
        }
    }

    // MARK: - Rules

    var labelRules: [LabelRule] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "labelRules"),
                  let rules = try? JSONDecoder().decode([LabelRule].self, from: data) else { return [] }
            return rules
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "labelRules")
            }
        }
    }

    var manualLabels: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "manualLabels") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "manualLabels") }
    }

    // MARK: - Computed

    var swiftFontWeight: Font.Weight {
        switch fontWeight {
        case 1: return .ultraLight
        case 2: return .thin
        case 3: return .light
        case 4: return .regular
        case 5: return .medium
        case 6: return .semibold
        case 7: return .bold
        case 8: return .heavy
        case 9: return .black
        default: return .medium
        }
    }

    var nsFontWeight: NSFont.Weight {
        switch fontWeight {
        case 1: return .ultraLight
        case 2: return .thin
        case 3: return .light
        case 4: return .regular
        case 5: return .medium
        case 6: return .semibold
        case 7: return .bold
        case 8: return .heavy
        case 9: return .black
        default: return .medium
        }
    }

    // MARK: - Private

    private func stored(_ key: String, default defaultValue: Double) -> Double {
        UserDefaults.standard.object(forKey: key) != nil
            ? UserDefaults.standard.double(forKey: key)
            : defaultValue
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }
}
