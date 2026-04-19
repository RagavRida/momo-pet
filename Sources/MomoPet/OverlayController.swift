import AppKit
import SceneKit

final class OverlayController {
    private var window: NSWindow!
    private var sceneView: PetSceneView!
    private(set) var pet: Momo!
    private(set) var behavior: BehaviorController!
    let mimic = Mimic()
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    func start() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let visible = screen.visibleFrame
        // Y of dock's top edge in scene coords (scene origin = screen center)
        let dockLineSceneY = visible.minY - frame.height/2 + 70

        window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.acceptsMouseMovedEvents = true

        sceneView = PetSceneView(frame: frame, options: nil)
        sceneView.autoresizingMask = [.width, .height]
        sceneView.backgroundColor = .clear
        sceneView.allowsCameraControl = false
        sceneView.antialiasingMode = .multisampling4X

        let scene = SCNScene()
        sceneView.scene = scene

        let camera = SCNNode()
        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.orthographicScale = Double(frame.height) / 2
        cam.zNear = 1
        cam.zFar = 5000
        cam.automaticallyAdjustsZRange = true
        camera.camera = cam
        camera.position = SCNVector3(0, 0, 800)
        scene.rootNode.addChildNode(camera)
        sceneView.pointOfView = camera

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 600
        ambient.light?.color = NSColor(white: 1.0, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 800
        key.position = SCNVector3(200, 400, 500)
        key.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/6, 0)
        scene.rootNode.addChildNode(key)

        pet = Momo()
        pet.node.position = SCNVector3(0, dockLineSceneY, 0)
        scene.rootNode.addChildNode(pet.node)

        window.contentView = sceneView
        window.orderFrontRegardless()

        behavior = BehaviorController(pet: pet, sceneView: sceneView, window: window, screenFrame: frame, dockLineY: dockLineSceneY)
        behavior.start()

        // mimic ↔ behavior wiring
        mimic.onPlaybackStart = { [weak self] in
            self?.pet.startTalking()
            self?.pet.setMood(.excited)
        }
        mimic.onPlaybackEnd = { [weak self] in
            self?.pet.stopTalking()
            self?.pet.setMood(.happy)
        }

        installMouseMonitors()
    }

    /// Globally monitor cursor — toggle window click-through based on whether cursor is over Momo.
    private func installMouseMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.updateClickThrough()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.updateClickThrough()
            return event
        }
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateClickThrough()
            self?.behavior.tickCursorTracking()
        }
    }

    private func updateClickThrough() {
        guard let pet = pet else { return }
        let mouseLoc = NSEvent.mouseLocation
        let petScreen = pet.screenCenter(in: window)
        let radius: CGFloat = 110
        let dx = mouseLoc.x - petScreen.x
        let dy = mouseLoc.y - petScreen.y
        let inside = (dx*dx + dy*dy) <= radius*radius
        if behavior?.isDragging == true {
            window.ignoresMouseEvents = false
        } else {
            window.ignoresMouseEvents = !inside
        }
    }
}

/// SCNView subclass that forwards mouse events to the behavior controller.
final class PetSceneView: SCNView {
    weak var behavior: BehaviorController?

    override func mouseDown(with event: NSEvent) {
        behavior?.handleMouseDown(at: convert(event.locationInWindow, from: nil))
    }
    override func mouseDragged(with event: NSEvent) {
        behavior?.handleMouseDragged(at: convert(event.locationInWindow, from: nil))
    }
    override func mouseUp(with event: NSEvent) {
        behavior?.handleMouseUp(at: convert(event.locationInWindow, from: nil))
    }
}
