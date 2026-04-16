import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.labelyourwindow.app", category: "OverlayManager")

@Observable
final class OverlayManager {
    let settings: SettingsManager
    private var overlayWindows: [String: OverlayWindow] = [:]
    private var fadeTasks: [String: Task<Void, Never>] = [:]
    private var customPositions: [String: CGPoint] = [:]
    private var currentKey: String?
    private var flagsMonitor: Any?

    init(settings: SettingsManager) {
        self.settings = settings
        setupDragModifier()
    }

    /// Option key toggles drag mode on all visible overlays
    private func setupDragModifier() {
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let optionDown = event.modifierFlags.contains(.option)
            self?.setAllDraggable(optionDown)
            return event
        }
    }

    private func setAllDraggable(_ draggable: Bool) {
        for (_, overlay) in overlayWindows where overlay.isVisible {
            overlay.setDraggable(draggable)
        }
    }

    func showLabel(_ label: String, for window: WindowInfo, isPinned: Bool) {
        let key = window.identifier.key

        // Cancel any pending fade for this window
        fadeTasks[key]?.cancel()
        fadeTasks.removeValue(forKey: key)

        // Hide previous overlay if different window
        if let prevKey = currentKey, prevKey != key {
            hideLabel(for: prevKey, animated: true)
        }
        currentKey = key

        let overlay = getOrCreateOverlay(for: key)

        // Set content
        let hostingView = NSHostingView(
            rootView: LabelOverlayView(label: label, settings: settings)
        )
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)
        overlay.contentView = hostingView
        overlay.setContentSize(fittingSize)

        // Position the overlay
        let position: CGPoint
        if let custom = customPositions[key] {
            position = custom
        } else {
            position = calculatePosition(for: window, overlaySize: fittingSize)
        }
        overlay.setFrameOrigin(position)

        // Wire up drag callback
        overlay.onDragMoved = { [weak self] newOrigin in
            self?.customPositions[key] = newOrigin
        }

        // Fade in
        if overlay.alphaValue < 0.01 || !overlay.isVisible {
            overlay.alphaValue = 0
            overlay.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                overlay.animator().alphaValue = 1.0
            }
        } else {
            overlay.orderFrontRegardless()
            overlay.alphaValue = 1.0
        }

        // Schedule fade out if not pinned
        if !isPinned {
            scheduleFadeOut(key: key)
        }

        logger.info("Overlay positioned at (\(Int(position.x)), \(Int(position.y))) size \(Int(fittingSize.width))x\(Int(fittingSize.height))")
    }

    func hideAll() {
        for (key, _) in fadeTasks {
            fadeTasks[key]?.cancel()
        }
        fadeTasks.removeAll()
        for (_, window) in overlayWindows {
            window.alphaValue = 0
            window.orderOut(nil)
        }
        currentKey = nil
    }

    func hideLabel(for key: String, animated: Bool = true) {
        guard let overlay = overlayWindows[key] else { return }
        fadeTasks[key]?.cancel()
        fadeTasks.removeValue(forKey: key)

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = settings.fadeAnimationDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                overlay.animator().alphaValue = 0
            }, completionHandler: {
                overlay.orderOut(nil)
            })
        } else {
            overlay.alphaValue = 0
            overlay.orderOut(nil)
        }
    }

    // MARK: - Private

    private func getOrCreateOverlay(for key: String) -> OverlayWindow {
        if let existing = overlayWindows[key] {
            return existing
        }
        let overlay = OverlayWindow(contentRect: .zero)
        overlayWindows[key] = overlay
        return overlay
    }

    private func scheduleFadeOut(key: String) {
        fadeTasks[key] = Task { @MainActor [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(for: .seconds(self.settings.fadeDuration))
            guard !Task.isCancelled else { return }
            self.hideLabel(for: key, animated: true)
        }
    }

    // MARK: - Position calculation

    private func calculatePosition(for window: WindowInfo, overlaySize: NSSize) -> CGPoint {
        let inset = settings.labelInset
        let windowFrame = window.frame // CG coordinates (origin = top-left of main display)

        // Get main screen height for CG→NS conversion
        guard let mainScreen = NSScreen.screens.first else {
            return CGPoint(x: 100, y: 100)
        }
        let mainScreenHeight = mainScreen.frame.height

        // Convert CG origin (top-left) to NS origin (bottom-left)
        // CG: y=0 at top, increases downward
        // NS: y=0 at bottom, increases upward
        let nsWindowLeft = windowFrame.origin.x
        let nsWindowBottom = mainScreenHeight - windowFrame.origin.y - windowFrame.size.height
        let nsWindowRight = nsWindowLeft + windowFrame.size.width
        let nsWindowTop = nsWindowBottom + windowFrame.size.height

        let position: CGPoint
        switch settings.labelPosition {
        case .topRight:
            position = CGPoint(
                x: nsWindowRight - overlaySize.width - inset,
                y: nsWindowTop - overlaySize.height - inset
            )
        case .topLeft:
            position = CGPoint(
                x: nsWindowLeft + inset,
                y: nsWindowTop - overlaySize.height - inset
            )
        case .topCenter:
            position = CGPoint(
                x: nsWindowLeft + (windowFrame.width - overlaySize.width) / 2,
                y: nsWindowTop - overlaySize.height - inset
            )
        case .bottomLeft:
            position = CGPoint(
                x: nsWindowLeft + inset,
                y: nsWindowBottom + inset
            )
        case .bottomRight:
            position = CGPoint(
                x: nsWindowRight - overlaySize.width - inset,
                y: nsWindowBottom + inset
            )
        case .center:
            position = CGPoint(
                x: nsWindowLeft + (windowFrame.width - overlaySize.width) / 2,
                y: nsWindowBottom + (windowFrame.height - overlaySize.height) / 2
            )
        }

        return clampToVisibleScreens(position, overlaySize: overlaySize)
    }

    private func clampToVisibleScreens(_ point: CGPoint, overlaySize: NSSize) -> CGPoint {
        // Find the screen that contains this point
        let testRect = NSRect(origin: point, size: overlaySize)
        let screen = NSScreen.screens.first { $0.frame.intersects(testRect) } ?? NSScreen.main

        guard let visibleFrame = screen?.visibleFrame else { return point }

        let x = max(visibleFrame.minX + 4, min(point.x, visibleFrame.maxX - overlaySize.width - 4))
        let y = max(visibleFrame.minY + 4, min(point.y, visibleFrame.maxY - overlaySize.height - 4))
        return CGPoint(x: x, y: y)
    }
}
