import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.labelyourwindow.app", category: "OverlayManager")

@Observable
final class OverlayManager {
    let settings: SettingsManager
    weak var labelManager: LabelManager?

    private var overlayWindows: [String: OverlayWindow] = [:]
    private var fadeTasks: [String: Task<Void, Never>] = [:]
    private var userDraggedPositions: [String: CGPoint] = [:]
    private var overlayLabels: [String: String] = [:]
    private var resolvedWindowInfo: [String: WindowInfo] = [:]
    private var editingText: [String: String] = [:]
    private var currentKey: String?
    private var globalMoveMonitor: Any?
    private var localMoveMonitor: Any?
    private var mouseUpMonitor: Any?

    init(settings: SettingsManager) {
        self.settings = settings
        loadPositions()
        setupHoverDetection()
    }

    deinit {
        if let m = globalMoveMonitor { NSEvent.removeMonitor(m) }
        if let m = localMoveMonitor { NSEvent.removeMonitor(m) }
        if let m = mouseUpMonitor { NSEvent.removeMonitor(m) }
    }

    /// Hover over label to enable drag
    private func setupHoverDetection() {
        globalMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }

        localMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }

        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self = self else { return event }
            for (_, overlay) in self.overlayWindows where overlay.isDragging {
                overlay.endDrag()
            }
            return event
        }
    }

    private func handleMouseMoved() {
        let mouseLocation = NSEvent.mouseLocation

        for (_, overlay) in overlayWindows where overlay.isVisible && overlay.alphaValue > 0.01 {
            guard !overlay.isEditMode else { continue }
            let overlayFrame = overlay.frame
            if overlayFrame.contains(mouseLocation) {
                if overlay.ignoresMouseEvents {
                    overlay.ignoresMouseEvents = false
                    overlay.showHoverFeedback(true)
                }
            } else {
                if !overlay.ignoresMouseEvents && !overlay.isDragging {
                    overlay.ignoresMouseEvents = true
                    overlay.showHoverFeedback(false)
                }
            }
        }
    }

    func showOrUpdateLabel(_ label: String, for window: WindowInfo, isPinned: Bool) {
        let key = window.identifier.key

        fadeTasks[key]?.cancel()
        fadeTasks.removeValue(forKey: key)

        // Hide previous overlay only in single-window mode
        if !settings.multiWindowMode {
            if let prevKey = currentKey, prevKey != key {
                hideLabel(for: prevKey, animated: true)
            }
            currentKey = key
        }

        resolvedWindowInfo[key] = window

        let overlay = getOrCreateOverlay(for: key)

        // Update content if label changed (and not in edit mode)
        if overlayLabels[key] != label && !overlay.isEditMode {
            rebuildDisplayContent(for: key, label: label, overlay: overlay)
            overlayLabels[key] = label
        }

        // Position: user-dragged takes priority, otherwise recalculate from window frame
        let overlaySize = overlay.frame.size
        let position: CGPoint
        if let dragged = userDraggedPositions[key] {
            position = dragged
        } else {
            position = calculatePosition(for: window, overlaySize: overlaySize)
        }
        // Only reposition if moved more than 2pt to avoid CGWindowList precision jitter
        let current = overlay.frame.origin
        if abs(position.x - current.x) > 2 || abs(position.y - current.y) > 2 {
            overlay.setFrameOrigin(position)
        }

        // Wire drag callback
        overlay.onDragMoved = { [weak self] newOrigin in
            self?.userDraggedPositions[key] = newOrigin
            self?.savePositions()
        }

        // Wire double-click for edit mode
        overlay.onDoubleClick = { [weak self] in
            self?.enterEditMode(for: key)
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
        } else if !overlay.isEditMode {
            overlay.orderFrontRegardless()
            overlay.alphaValue = 1.0
        }

        if !isPinned {
            scheduleFadeOut(key: key)
        }

        logger.info("Overlay positioned at (\(Int(position.x)), \(Int(position.y))) size \(Int(overlaySize.width))x\(Int(overlaySize.height))")
    }

    // Legacy name for compatibility
    func showLabel(_ label: String, for window: WindowInfo, isPinned: Bool) {
        showOrUpdateLabel(label, for: window, isPinned: isPinned)
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

    func removeOverlays(notIn activeKeys: Set<String>) {
        let staleKeys = Set(overlayWindows.keys).subtracting(activeKeys)
        for key in staleKeys {
            hideLabel(for: key, animated: true)
            overlayWindows.removeValue(forKey: key)
            overlayLabels.removeValue(forKey: key)
            fadeTasks.removeValue(forKey: key)
            resolvedWindowInfo.removeValue(forKey: key)
            editingText.removeValue(forKey: key)
        }
    }

    // MARK: - Edit mode

    func enterEditMode(for key: String) {
        guard let overlay = overlayWindows[key] else { return }
        guard !overlay.isEditMode else { return }

        fadeTasks[key]?.cancel()
        fadeTasks.removeValue(forKey: key)

        editingText[key] = overlayLabels[key] ?? ""
        overlay.ignoresMouseEvents = false
        overlay.isEditMode = true
        rebuildEditContent(for: key, overlay: overlay)

        let overlaySize = overlay.contentView?.fittingSize ?? overlay.frame.size
        overlay.setContentSize(overlaySize)
        overlay.setFrameOrigin(clampToVisibleScreens(overlay.frame.origin, overlaySize: overlaySize))
    }

    func commitEdit(for key: String) {
        let text = editingText[key]?.trimmingCharacters(in: .whitespaces) ?? ""
        if let info = resolvedWindowInfo[key] {
            if text.isEmpty {
                labelManager?.clearWindowLabel(for: info)
            } else {
                labelManager?.setWindowLabel(text, for: info)
            }
            labelManager?.invalidateCache(for: info.identifier)
        }
        exitEditMode(for: key)

        // Refresh overlay with new label
        if let info = resolvedWindowInfo[key],
           let assignment = labelManager?.labelForWindow(info) {
            let isPinned = assignment.isPinned || settings.displayMode == .pinned || settings.multiWindowMode
            showOrUpdateLabel(assignment.label, for: info, isPinned: isPinned)
        }
    }

    func cancelEdit(for key: String) {
        editingText.removeValue(forKey: key)
        exitEditMode(for: key)
        // Restore display view with original label
        if let overlay = overlayWindows[key] {
            let label = overlayLabels[key] ?? ""
            rebuildDisplayContent(for: key, label: label, overlay: overlay)
        }
    }

    private func exitEditMode(for key: String) {
        guard let overlay = overlayWindows[key] else { return }
        overlay.isEditMode = false
        overlay.ignoresMouseEvents = true
    }

    // MARK: - Content rebuild

    private func rebuildDisplayContent(for key: String, label: String, overlay: OverlayWindow) {
        let hostingView = NSHostingView(
            rootView: LabelOverlayView(label: label, settings: settings)
        )
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)
        overlay.contentView = hostingView
        overlay.setContentSize(fittingSize)
    }

    private func rebuildEditContent(for key: String, overlay: OverlayWindow) {
        let binding = Binding<String>(
            get: { [weak self] in self?.editingText[key] ?? "" },
            set: { [weak self] in self?.editingText[key] = $0 }
        )
        let label = overlayLabels[key] ?? ""
        let view = LabelOverlayView(
            label: label,
            settings: settings,
            isEditing: true,
            editText: binding,
            onCommit: { [weak self] in self?.commitEdit(for: key) },
            onCancel: { [weak self] in self?.cancelEdit(for: key) }
        )
        let hostingView = NSHostingView(rootView: view)
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)
        overlay.contentView = hostingView
        overlay.setContentSize(fittingSize)
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

    // MARK: - Position persistence

    private func loadPositions() {
        guard let data = UserDefaults.standard.data(forKey: "overlayPositions"),
              let dict = try? JSONDecoder().decode([String: [Double]].self, from: data) else { return }
        userDraggedPositions = dict.mapValues { CGPoint(x: $0[0], y: $0[1]) }
    }

    private func savePositions() {
        let dict = userDraggedPositions.mapValues { [$0.x, $0.y] }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: "overlayPositions")
        }
    }

    // MARK: - Position calculation

    private func calculatePosition(for window: WindowInfo, overlaySize: NSSize) -> CGPoint {
        let inset = settings.labelInset
        let windowFrame = window.frame

        guard let mainScreen = NSScreen.screens.first else {
            return CGPoint(x: 100, y: 100)
        }
        let mainScreenHeight = mainScreen.frame.height

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
        let testRect = NSRect(origin: point, size: overlaySize)
        let screen = NSScreen.screens.first { $0.frame.intersects(testRect) } ?? NSScreen.main

        guard let visibleFrame = screen?.visibleFrame else { return point }

        let x = max(visibleFrame.minX + 4, min(point.x, visibleFrame.maxX - overlaySize.width - 4))
        let y = max(visibleFrame.minY + 4, min(point.y, visibleFrame.maxY - overlaySize.height - 4))
        return CGPoint(x: x, y: y)
    }
}
