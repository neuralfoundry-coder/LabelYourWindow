import AppKit
import os.log

private let logger = Logger(subsystem: "com.labelyourwindow.app", category: "AppDelegate")

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsManager()
    var windowObserver: WindowObserver!
    var labelManager: LabelManager!
    var overlayManager: OverlayManager!
    private var observationTask: Task<Void, Never>?
    private var multiWindowPollTask: Task<Void, Never>?
    private var accessibilityPollTask: Task<Void, Never>?
    private var isObserving = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("LabelYourWindow launched. AX trusted: \(AccessibilityHelper.isAccessibilityEnabled)")
        AccessibilityHelper.requestAccessibilityIfNeeded()

        windowObserver = WindowObserver()
        labelManager = LabelManager(settings: settings)
        overlayManager = OverlayManager(settings: settings)
        overlayManager.labelManager = labelManager

        setupPipeline()
        setupMultiWindowLoop()

        if AccessibilityHelper.isAccessibilityEnabled {
            startObserving()
        } else {
            waitForAccessibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        observationTask?.cancel()
        multiWindowPollTask?.cancel()
        accessibilityPollTask?.cancel()
        windowObserver.stopObserving()
        overlayManager.hideAll()
    }

    private func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        windowObserver.startObserving()
        logger.info("Window observation started")
    }

    private func waitForAccessibility() {
        logger.info("Waiting for accessibility permission...")
        accessibilityPollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                if AccessibilityHelper.isAccessibilityEnabled {
                    logger.info("Accessibility permission granted!")
                    self?.startObserving()
                    return
                }
            }
        }
    }

    private func setupPipeline() {
        observationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                let previousWindow = self.windowObserver.currentWindow

                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.windowObserver.currentWindow
                    } onChange: {
                        continuation.resume()
                    }
                }

                guard !Task.isCancelled else { return }
                guard self.settings.isEnabled else { continue }
                guard let window = self.windowObserver.currentWindow else { continue }

                if let prev = previousWindow, prev == window { continue }

                let assignment = self.labelManager.labelForWindow(window)
                guard !assignment.label.isEmpty else { continue }

                let isPinned = assignment.isPinned || self.settings.displayMode == .pinned || self.settings.multiWindowMode
                logger.info("Label: '\(assignment.label, privacy: .public)' for \(window.appName, privacy: .public) [pinned:\(isPinned)]")
                self.overlayManager.showOrUpdateLabel(assignment.label, for: window, isPinned: isPinned)
            }
        }
    }

    private func setupMultiWindowLoop() {
        multiWindowPollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self = self,
                      self.settings.isEnabled,
                      self.settings.multiWindowMode else { continue }

                let windows = self.windowObserver.allVisibleWindows()
                var activeKeys = Set<String>()

                for window in windows {
                    let assignment = self.labelManager.labelForWindow(window)
                    guard !assignment.label.isEmpty else { continue }
                    self.overlayManager.showOrUpdateLabel(assignment.label, for: window, isPinned: true)
                    activeKeys.insert(window.identifier.key)
                }

                self.overlayManager.removeOverlays(notIn: activeKeys)
            }
        }
    }
}
