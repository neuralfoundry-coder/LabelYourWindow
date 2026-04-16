import AppKit
import ApplicationServices

struct WindowIdentifier: Hashable, Codable {
    let pid: pid_t
    let windowNumber: Int

    var key: String { "\(pid):\(windowNumber)" }
}

struct WindowInfo: Equatable {
    let identifier: WindowIdentifier
    let appName: String
    let bundleID: String?
    let windowTitle: String
    let frame: CGRect
    let axElement: AXUIElement

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.identifier == rhs.identifier
            && lhs.windowTitle == rhs.windowTitle
            && lhs.frame == rhs.frame
    }
}
