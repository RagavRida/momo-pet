import AppKit

/// Tiny floating speech bubble that appears above Momo and fades after a few seconds.
final class SpeechBubble {
    private var window: NSWindow?
    private let text: String
    private let anchor: CGPoint

    init(text: String, anchor: CGPoint) {
        self.text = text
        self.anchor = anchor
    }

    func show(duration: TimeInterval = 2.4) {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor(white: 0.1, alpha: 1.0)
        label.alignment = .center
        label.sizeToFit()

        let padding: CGFloat = 12
        let size = NSSize(width: label.frame.width + padding*2, height: label.frame.height + padding)
        let origin = NSPoint(x: anchor.x - size.width/2, y: anchor.y)

        let w = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.level = .floating
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let bg = BubbleView(frame: NSRect(origin: .zero, size: size))
        label.frame.origin = NSPoint(x: padding, y: padding/2)
        bg.addSubview(label)
        w.contentView = bg
        w.alphaValue = 0
        w.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            w.animator().alphaValue = 1.0
        }

        window = w

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.dismiss()
        }
    }

    func dismiss() {
        guard let w = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            w.animator().alphaValue = 0
        }, completionHandler: {
            w.orderOut(nil)
        })
        window = nil
    }
}

private final class BubbleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 12, yRadius: 12)
        NSColor(white: 1.0, alpha: 0.95).setFill()
        path.fill()
        NSColor(white: 0.85, alpha: 1.0).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}
