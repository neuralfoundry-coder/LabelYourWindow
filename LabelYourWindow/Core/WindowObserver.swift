import AppKit
import ApplicationServices
import os.log

private let logger = Logger(subsystem: "com.labelyourwindow.app", category: "WindowObserver")

@Observable
final class WindowObserver {
    private(set) var currentWindow: WindowInfo?

    private var axObservers: [pid_t: AXObserver] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var currentAppPID: pid_t = 0

    func startObserving() {
        let nc = NSWorkspace.shared.notificationCenter

        let activateToken = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.handleAppActivated(app)
        }
        workspaceObservers.append(activateToken)

        // Observe the currently active app on start
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            handleAppActivated(frontApp)
        }
    }

    func stopObserving() {
        let nc = NSWorkspace.shared.notificationCenter
        for token in workspaceObservers {
            nc.removeObserver(token)
        }
        workspaceObservers.removeAll()

        for (_, observer) in axObservers {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        axObservers.removeAll()
        currentAppPID = 0
    }

    // MARK: - App activation

    private func handleAppActivated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        logger.info("App activated: \(app.localizedName ?? "Unknown", privacy: .public) (pid: \(pid))")

        // Remove observer for previous app
        if currentAppPID != 0 && currentAppPID != pid {
            removeAXObserver(for: currentAppPID)
        }
        currentAppPID = pid

        // Add observer for new app
        addAXObserver(for: pid)

        // Read current focused window (with short delay for app readiness)
        let appName = app.localizedName ?? "Unknown"
        let bundleID = app.bundleIdentifier
        Task { @MainActor [weak self] in
            // Small delay to let the app finish its focus transition
            try? await Task.sleep(for: .milliseconds(150))
            self?.readFocusedWindow(pid: pid, appName: appName, bundleID: bundleID)
        }
    }

    // MARK: - AX Observer management

    private func addAXObserver(for pid: pid_t) {
        guard axObservers[pid] == nil else { return }

        var observer: AXObserver?
        let result = AXObserverCreate(pid, axObserverCallback, &observer)
        guard result == .success, let observer = observer else {
            logger.info("Failed to create AXObserver for pid \(pid): \(result.rawValue)")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let notifications: [CFString] = [
            kAXFocusedWindowChangedNotification as CFString,
            kAXWindowMovedNotification as CFString,
            kAXWindowResizedNotification as CFString,
            kAXTitleChangedNotification as CFString,
        ]

        for notif in notifications {
            AXObserverAddNotification(observer, appElement, notif, selfPtr)
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        axObservers[pid] = observer
    }

    private func removeAXObserver(for pid: pid_t) {
        guard let observer = axObservers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
    }

    // MARK: - Focus reading

    func handleAXNotification(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        readFocusedWindow(pid: pid, appName: app.localizedName ?? "Unknown", bundleID: app.bundleIdentifier)
    }

    private func readFocusedWindow(pid: pid_t, appName: String, bundleID: String?, retryCount: Int = 0) {
        let appElement = AXUIElementCreateApplication(pid)

        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)
        guard result == .success, let windowElement = windowValue else {
            // Retry with increasing delay for apps that are slow to respond
            if retryCount < 3 && (result.rawValue == -25212 || result.rawValue == -25204) {
                let delay = [300, 500, 1000][retryCount]
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(delay))
                    self?.readFocusedWindow(pid: pid, appName: appName, bundleID: bundleID, retryCount: retryCount + 1)
                }
                return
            }
            // Fallback: use CGWindowList to get window info
            if let fallbackInfo = windowInfoFromCGWindowList(pid: pid, appName: appName, bundleID: bundleID) {
                if currentWindow != fallbackInfo {
                    logger.info("Window changed (CGFallback): \(fallbackInfo.windowTitle, privacy: .public) [\(appName, privacy: .public)]")
                    currentWindow = fallbackInfo
                }
                return
            }
            logger.info("No focused window for \(appName, privacy: .public) (AX result: \(result.rawValue))")
            return
        }

        let axWindow = windowElement as! AXUIElement

        // Read title
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
        let title = titleValue as? String ?? ""

        // Read position
        var positionValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue)
        var position = CGPoint.zero
        if let posRef = positionValue {
            AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        }

        // Read size
        var sizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue)
        var size = CGSize.zero
        if let sizeRef = sizeValue {
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        }

        // Get window number from CGWindowList for stable ID
        let windowNumber = windowNumberFromAX(pid: pid, position: position, size: size)

        let info = WindowInfo(
            identifier: WindowIdentifier(pid: pid, windowNumber: windowNumber),
            appName: appName,
            bundleID: bundleID,
            windowTitle: title,
            frame: CGRect(origin: position, size: size),
            axElement: axWindow
        )

        if currentWindow != info {
            logger.info("Window changed: \(title, privacy: .public) [\(appName, privacy: .public)]")
            currentWindow = info
        }
    }

    private func windowNumberFromAX(pid: pid_t, position: CGPoint, size: CGSize) -> Int {
        let options = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return Int(pid)
        }

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let number = window[kCGWindowNumber as String] as? Int,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat else { continue }

            // Match by position (approximate)
            if abs(x - position.x) < 2 && abs(y - position.y) < 2 {
                return number
            }
        }

        return Int(pid)
    }

    private func windowInfoFromCGWindowList(pid: pid_t, appName: String, bundleID: String?) -> WindowInfo? {
        let options = CGWindowListOption([.optionOnScreenOnly, .excludeDesktopElements])
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Find the frontmost (lowest layer) normal window for this PID
        var bestWindow: [String: Any]?
        var bestLayer = Int.max

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer >= 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? CGFloat,
                  width > 100 else { continue } // skip tiny/utility windows

            if layer < bestLayer {
                bestLayer = layer
                bestWindow = window
            }
        }

        guard let win = bestWindow,
              let number = win[kCGWindowNumber as String] as? Int,
              let bounds = win[kCGWindowBounds as String] as? [String: Any],
              let x = bounds["X"] as? CGFloat,
              let y = bounds["Y"] as? CGFloat,
              let w = bounds["Width"] as? CGFloat,
              let h = bounds["Height"] as? CGFloat else { return nil }

        let title = win[kCGWindowName as String] as? String ?? ""
        let frame = CGRect(x: x, y: y, width: w, height: h)
        let axElement = AXUIElementCreateApplication(pid)

        return WindowInfo(
            identifier: WindowIdentifier(pid: pid, windowNumber: number),
            appName: appName,
            bundleID: bundleID,
            windowTitle: title,
            frame: frame,
            axElement: axElement
        )
    }
}

// MARK: - AX Observer C callback

private func axObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let windowObserver = Unmanaged<WindowObserver>.fromOpaque(refcon).takeUnretainedValue()

    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)

    DispatchQueue.main.async {
        windowObserver.handleAXNotification(pid: pid)
    }
}
