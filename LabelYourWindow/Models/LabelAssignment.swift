import Foundation

struct LabelAssignment: Codable, Equatable {
    var label: String
    var source: LabelSource
    var customX: Double?
    var customY: Double?
    var isPinned: Bool

    enum LabelSource: String, Codable {
        case autoDetected
        case rule
        case manual
        case windowLevel
    }

    init(
        label: String,
        source: LabelSource = .autoDetected,
        customX: Double? = nil,
        customY: Double? = nil,
        isPinned: Bool = false
    ) {
        self.label = label
        self.source = source
        self.customX = customX
        self.customY = customY
        self.isPinned = isPinned
    }
}
