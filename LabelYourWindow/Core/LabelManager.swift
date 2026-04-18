import Foundation

@Observable
final class LabelManager {
    private let settings: SettingsManager
    private var labelCache: [String: LabelAssignment] = [:]
    private var sessionWindowLabels: [String: String] = [:]

    private(set) var currentLabel: String = ""
    private(set) var currentAssignment: LabelAssignment?

    init(settings: SettingsManager) {
        self.settings = settings
    }

    func labelForWindow(_ info: WindowInfo) -> LabelAssignment {
        let cacheKey = info.identifier.key

        // Return cached label if it exists
        if let cached = labelCache[cacheKey] {
            currentLabel = cached.label
            currentAssignment = cached
            return cached
        }

        // First time seeing this window — resolve and cache
        let assignment = resolveLabel(for: info)
        labelCache[cacheKey] = assignment
        currentLabel = assignment.label
        currentAssignment = assignment
        return assignment
    }

    func setWindowLabel(_ label: String, for info: WindowInfo) {
        let key = info.identifier.key
        if label.isEmpty {
            sessionWindowLabels.removeValue(forKey: key)
        } else {
            sessionWindowLabels[key] = label
        }
        invalidateCache(for: info.identifier)
    }

    func clearWindowLabel(for info: WindowInfo) {
        setWindowLabel("", for: info)
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

        // Update cache
        let cacheKey = info.identifier.key
        if label.isEmpty {
            labelCache.removeValue(forKey: cacheKey)
        } else {
            labelCache[cacheKey] = LabelAssignment(label: label, source: .manual)
        }
    }

    func clearManualLabel(for info: WindowInfo) {
        setManualLabel("", for: info)
    }

    func invalidateCache(for identifier: WindowIdentifier) {
        labelCache.removeValue(forKey: identifier.key)
    }

    // MARK: - Label Resolution

    private func resolveLabel(for info: WindowInfo) -> LabelAssignment {
        // Priority 0: Session-scoped window-level label
        if let windowLabel = sessionWindowLabels[info.identifier.key] {
            return LabelAssignment(label: windowLabel, source: .windowLevel)
        }

        // Priority 1: Manual label
        let manualKey = manualKey(for: info)
        if let manual = settings.manualLabels[manualKey] {
            return LabelAssignment(label: manual, source: .manual)
        }

        // Priority 2: User-defined rules
        if let ruleLabel = matchRule(for: info) {
            return LabelAssignment(label: ruleLabel, source: .rule)
        }

        // Priority 3: Auto-detection from window title
        let autoLabel = WindowTitleParser.parse(
            title: info.windowTitle,
            appName: info.appName,
            bundleID: info.bundleID
        )
        return LabelAssignment(label: autoLabel, source: .autoDetected)
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
