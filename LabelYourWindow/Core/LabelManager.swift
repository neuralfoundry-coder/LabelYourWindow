import Foundation

@Observable
final class LabelManager {
    private let settings: SettingsManager

    private(set) var currentLabel: String = ""
    private(set) var currentAssignment: LabelAssignment?

    init(settings: SettingsManager) {
        self.settings = settings
    }

    func labelForWindow(_ info: WindowInfo) -> LabelAssignment {
        // Priority 1: Manual label
        let manualKey = manualKey(for: info)
        if let manual = settings.manualLabels[manualKey] {
            let assignment = LabelAssignment(label: manual, source: .manual)
            currentLabel = manual
            currentAssignment = assignment
            return assignment
        }

        // Priority 2: User-defined rules
        if let ruleLabel = matchRule(for: info) {
            let assignment = LabelAssignment(label: ruleLabel, source: .rule)
            currentLabel = ruleLabel
            currentAssignment = assignment
            return assignment
        }

        // Priority 3: Auto-detection from window title
        let autoLabel = WindowTitleParser.parse(
            title: info.windowTitle,
            appName: info.appName,
            bundleID: info.bundleID
        )
        let assignment = LabelAssignment(label: autoLabel, source: .autoDetected)
        currentLabel = autoLabel
        currentAssignment = assignment
        return assignment
    }

    func setManualLabel(_ label: String, for info: WindowInfo) {
        let key = manualKey(for: info)
        var labels = settings.manualLabels
        if label.isEmpty {
            labels.removeValue(forKey: key)
        } else {
            labels[key] = label
        }
        settings.manualLabels = labels
    }

    func clearManualLabel(for info: WindowInfo) {
        setManualLabel("", for: info)
    }

    // MARK: - Private

    private func manualKey(for info: WindowInfo) -> String {
        // Use bundleID + window title hash for stable identification
        let base = info.bundleID ?? info.appName
        return "\(base):\(info.windowTitle)"
    }

    private func matchRule(for info: WindowInfo) -> String? {
        let rules = settings.labelRules
            .filter(\.isEnabled)
            .sorted { $0.priority > $1.priority }

        for rule in rules {
            let target: String
            switch rule.matchType {
            case .appName: target = info.appName
            case .windowTitle: target = info.windowTitle
            case .bundleID: target = info.bundleID ?? ""
            }

            let matched: Bool
            if rule.isRegex {
                matched = (try? target.range(of: rule.matchPattern, options: .regularExpression)) != nil
            } else {
                matched = target.localizedCaseInsensitiveContains(rule.matchPattern)
            }

            if matched {
                return applyTemplate(rule.labelTemplate, info: info)
            }
        }

        return nil
    }

    private func applyTemplate(_ template: String, info: WindowInfo) -> String {
        var result = template
        result = result.replacingOccurrences(of: "{title}", with: info.windowTitle)
        result = result.replacingOccurrences(of: "{app}", with: info.appName)
        result = result.replacingOccurrences(of: "{bundle}", with: info.bundleID ?? "")
        return result
    }
}
