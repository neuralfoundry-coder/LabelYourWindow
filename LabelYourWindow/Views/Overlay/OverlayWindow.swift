import AppKit

final class OverlayWindow: NSPanel {
    var onDragMoved: ((CGPoint) -> Void)?
    var onDoubleClick: (() -> Void)?

    private var initialMouseLocation: CGPoint = .zero
    private var initialWindowOrigin: CGPoint = .zero
    private(set) var isDragging = false
    private var _isEditMode: Bool = false

    var isEditMode: Bool {
        get { _isEditMode }
        set {
            _isEditMode = newValue
            if newValue {
                makeKeyAndOrderFront(nil)
            } else {
                resignKey()
            }
        }
    }

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
        // Click-through by default - hover enables drag
        ignoresMouseEvents = true
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { _isEditMode }
    override var canBecomeMain: Bool { false }

    func showHoverFeedback(_ show: Bool) {
        if show {
            NSCursor.openHand.push()
        } else {
            NSCursor.pop()
        }
    }

    func endDrag() {
        if isDragging {
            isDragging = false
            NSCursor.pop()
            onDragMoved?(frame.origin)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 && !_isEditMode {
            isDragging = false  // cancel any drag started on first click
            onDoubleClick?()
            return
        }
        NSCursor.closedHand.push()
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = frame.origin
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let currentMouse = NSEvent.mouseLocation
        let newOrigin = CGPoint(
            x: initialWindowOrigin.x + (currentMouse.x - initialMouseLocation.x),
            y: initialWindowOrigin.y + (currentMouse.y - initialMouseLocation.y)
        )
        setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            NSCursor.pop()
            onDragMoved?(frame.origin)
        }
    }
}
