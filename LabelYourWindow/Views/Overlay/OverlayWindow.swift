import AppKit

final class OverlayWindow: NSPanel {
    var onDragMoved: ((CGPoint) -> Void)?
    private var initialMouseLocation: CGPoint = .zero
    private var initialWindowOrigin: CGPoint = .zero
    private var dragging = false

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hasShadow = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        // Click-through by default - Option key enables drag
        ignoresMouseEvents = true
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func setDraggable(_ draggable: Bool) {
        ignoresMouseEvents = !draggable
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = frame.origin
        dragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragging else { return }
        let currentMouse = NSEvent.mouseLocation
        let newOrigin = CGPoint(
            x: initialWindowOrigin.x + (currentMouse.x - initialMouseLocation.x),
            y: initialWindowOrigin.y + (currentMouse.y - initialMouseLocation.y)
        )
        setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if dragging {
            dragging = false
            onDragMoved?(frame.origin)
        }
    }
}
