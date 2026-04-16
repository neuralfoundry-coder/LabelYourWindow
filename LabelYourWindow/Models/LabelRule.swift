import Foundation

struct LabelRule: Codable, Identifiable, Equatable {
    let id: UUID
    var isEnabled: Bool
    var matchType: MatchType
    var matchPattern: String
    var isRegex: Bool
    var labelTemplate: String
    var priority: Int

    enum MatchType: String, Codable, CaseIterable {
        case appName = "App Name"
        case windowTitle = "Window Title"
        case bundleID = "Bundle ID"
    }

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        matchType: MatchType = .appName,
        matchPattern: String = "",
        isRegex: Bool = false,
        labelTemplate: String = "",
        priority: Int = 0
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.matchType = matchType
        self.matchPattern = matchPattern
        self.isRegex = isRegex
        self.labelTemplate = labelTemplate
        self.priority = priority
    }
}
