import AppKit
import SceneKit

/// State machine + per-tick behavior driver for Momo.
final class BehaviorController {
    enum State {
        case idle
        case walking(target: SCNVector3)
        case dragging
        case sleeping
        case reacting
        case paused
    }

    private let pet: Momo
    private weak var sceneView: PetSceneView?
    private weak var window: NSWindow?
    private let screenFrame: CGRect
    private let dockLineY: CGFloat

    private(set) var state: State = .idle
    private var lastInteraction: Date = .init()
    private var nextWanderAt: Date = .init().addingTimeInterval(20)
    private var nextBlinkAt: Date = .init().addingTimeInterval(2)
    private var nextThoughtAt: Date = .init().addingTimeInterval(45)
    private var nextNudgeAt: Date = .init().addingTimeInterval(15 * 60)
    private var sessionStart: Date = .init()
    private var dragOffset: CGPoint = .zero
    private var lastDragPoint: CGPoint = .zero
    private var lastDragTime: Date = .init()
    private var dragVelocity: CGPoint = .zero
    private var paused = false
    private var clickCount = 0
    private var recentClickTimes: [Date] = []
    private var greeted = false

    private var bubble: SpeechBubble?
    private let voice = Voice()
    private let casualThoughts = ["hi!", "boop?", "hello", "yay", "what's up", "hi friend", "look at you", "hehe"]

    var isDragging: Bool {
        if case .dragging = state { return true }
        return false
    }

    init(pet: Momo, sceneView: PetSceneView, window: NSWindow, screenFrame: CGRect, dockLineY: CGFloat) {
        self.pet = pet
        self.sceneView = sceneView
        self.window = window
        self.screenFrame = screenFrame
        self.dockLineY = dockLineY
        sceneView.behavior = self
    }

    func start() {
        pet.breathe()
        pet.setMood(.happy)
        voice.onStart = { [weak self] in self?.pet.startTalking() }
        voice.onFinish = { [weak self] in self?.pet.stopTalking() }
        Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.greetByTimeOfDay()
        }
    }

    func setPaused(_ p: Bool) {
        paused = p
        if p { state = .paused } else { state = .idle }
    }

    func forceSleep() { enterSleep() }

    // MARK: - Per-frame tick

    private func tick() {
        guard !paused else { return }
        let now = Date()

        if now >= nextBlinkAt, !isAsleep, !isDragging {
            pet.blink()
            nextBlinkAt = now.addingTimeInterval(.random(in: 2.5...5.5))
        }

        if case .idle = state, now >= nextWanderAt {
            walkToRandomSpot()
            nextWanderAt = now.addingTimeInterval(.random(in: 25...50))
        }

        if case .idle = state, now >= nextThoughtAt {
            showThought()
            nextThoughtAt = now.addingTimeInterval(.random(in: 40...80))
        }

        if case .idle = state, now >= nextNudgeAt {
            contextualNudge()
            nextNudgeAt = now.addingTimeInterval(.random(in: 12 * 60 ... 22 * 60))
        }

        if case .idle = state, systemIdleSeconds() > 600 {
            // user has been away from keyboard >10min → Momo naps
            enterSleep()
        }

        if case .walking(let target) = state {
            let p = pet.node.presentation.position
            let dx = target.x - p.x, dy = target.y - p.y
            if (dx*dx + dy*dy) < 25 {
                state = .idle
            }
        }
    }

    // MARK: - Cursor tracking (~10Hz from OverlayController)

    func tickCursorTracking() {
        guard let window = window else { return }
        if isAsleep {
            let mouse = NSEvent.mouseLocation
            let petScreen = pet.screenCenter(in: window)
            let dx = mouse.x - petScreen.x
            let dy = mouse.y - petScreen.y
            if (dx*dx + dy*dy) < CGFloat(220*220) {
                wakeUp()
            }
            return
        }
        if isDragging { return }
        let mouse = NSEvent.mouseLocation
        let petScreen = pet.screenCenter(in: window)
        let dx = mouse.x - petScreen.x
        let dy = mouse.y - petScreen.y
        let mag: CGFloat = max(CGFloat(1), sqrt(dx*dx + dy*dy))
        let nx = dx / max(mag, CGFloat(220))
        let ny = dy / max(mag, CGFloat(220))
        pet.lookAt(direction: CGPoint(x: nx, y: ny))
    }

    // MARK: - Mouse handlers

    func handleMouseDown(at point: CGPoint) {
        lastInteraction = Date()
        if isAsleep { wakeUp(); return }
        let p = pet.node.presentation.position
        let viewCenter = CGPoint(x: (sceneView?.bounds.width ?? 0)/2 + CGFloat(p.x),
                                 y: (sceneView?.bounds.height ?? 0)/2 + CGFloat(p.y))
        dragOffset = CGPoint(x: point.x - viewCenter.x, y: point.y - viewCenter.y)
        lastDragPoint = point
        lastDragTime = Date()
        state = .dragging
        pet.surprised()
        pet.setMood(.surprised)
    }

    func handleMouseDragged(at point: CGPoint) {
        guard isDragging, let view = sceneView else { return }
        let now = Date()
        let dt = max(0.001, now.timeIntervalSince(lastDragTime))
        dragVelocity = CGPoint(x: (point.x - lastDragPoint.x) / CGFloat(dt),
                               y: (point.y - lastDragPoint.y) / CGFloat(dt))
        lastDragPoint = point
        lastDragTime = now
        let target = CGPoint(x: point.x - dragOffset.x - view.bounds.width/2,
                             y: point.y - dragOffset.y - view.bounds.height/2)
        pet.node.position = SCNVector3(Float(target.x), Float(target.y), 0)
    }

    func handleMouseUp(at point: CGPoint) {
        if isDragging {
            let toss = SCNAction.moveBy(x: dragVelocity.x * 0.15, y: dragVelocity.y * 0.15, z: 0, duration: 0.4)
            toss.timingMode = .easeOut
            pet.node.runAction(toss) { [weak self] in
                DispatchQueue.main.async { self?.settleAfterToss() }
            }
            state = .idle
            pet.setMood(.curious)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.pet.setMood(.happy)
            }
            lastInteraction = Date()
            return
        }
        clickReact()
    }

    private func settleAfterToss() {
        clampToDockLine()
        let speed = sqrt(dragVelocity.x*dragVelocity.x + dragVelocity.y*dragVelocity.y)
        if speed > 1800 {
            pet.squish(intensity: 0.55)
            getAngry(reason: "ow! 💢")
        } else {
            pet.squish(intensity: 0.7)
            pet.sparkle(count: 6)
        }
    }

    // MARK: - Behaviors

    private func clickReact() {
        state = .reacting
        clickCount += 1
        let now = Date()
        recentClickTimes.append(now)
        recentClickTimes = recentClickTimes.filter { now.timeIntervalSince($0) < 2.0 }

        let isSpam = recentClickTimes.count >= 4
        if isSpam {
            getAngry(reason: "stop poking me! 😤")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                if case .reacting = self?.state { self?.state = .idle }
            }
            lastInteraction = now
            return
        }

        pet.hop()
        pet.surprised()
        pet.wiggleArms()
        pet.sparkle(count: 10)

        if clickCount % 5 == 0 {
            pet.setMood(.excited)
            showBubble("you again! 💕")
        } else {
            pet.setMood(.happy)
            showThought()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            if case .reacting = self?.state { self?.state = .idle }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.pet.setMood(.content)
        }
        lastInteraction = now
    }

    private func getAngry(reason: String) {
        pet.setMood(.angry)
        showBubble(reason)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.pet.setMood(.curious)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.pet.setMood(.happy)
        }
    }

    private func walkToRandomSpot() {
        let halfW = CGFloat(screenFrame.width/2 - 140)
        let targetX = CGFloat.random(in: -halfW...halfW)
        let targetY = dockLineY + CGFloat.random(in: -10...20)
        let target = SCNVector3(targetX, targetY, 0)

        let from = pet.node.position
        let dx = target.x - from.x
        let distance = abs(dx)
        let duration = TimeInterval(distance / 220.0)

        let tilt: CGFloat = dx > 0 ? -0.08 : 0.08
        pet.node.runAction(.rotateTo(x: 0, y: 0, z: tilt, duration: 0.2))

        let bobUp = SCNAction.moveBy(x: 0, y: 12, z: 0, duration: 0.18)
        let bobDown = SCNAction.moveBy(x: 0, y: -12, z: 0, duration: 0.18)
        bobUp.timingMode = .easeOut
        bobDown.timingMode = .easeIn
        let bob = SCNAction.repeatForever(.sequence([bobUp, bobDown]))
        pet.node.runAction(bob, forKey: "bob")

        let move = SCNAction.move(to: target, duration: max(0.5, duration))
        move.timingMode = .easeInEaseOut
        pet.node.runAction(move) { [weak self] in
            self?.pet.node.removeAction(forKey: "bob")
            self?.pet.node.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
            self?.state = .idle
        }
        state = .walking(target: target)
    }

    private func clampToDockLine() {
        let halfW: CGFloat = screenFrame.width/2 - 100
        var p = pet.node.position
        p.x = max(-halfW, min(halfW, p.x))
        // settle vertically near dock line
        p.y = dockLineY
        pet.node.runAction(.move(to: p, duration: 0.3))
    }

    // MARK: - Sleep

    private var isAsleep: Bool {
        if case .sleeping = state { return true }
        return false
    }

    private func enterSleep() {
        guard !isAsleep else { return }
        state = .sleeping
        pet.setMood(.sleepy)
        pet.closeEyes()
        pet.node.removeAction(forKey: "bob")
        showBubble("zzz 🌙")
    }

    private func wakeUp() {
        guard isAsleep else { return }
        state = .idle
        pet.openEyes()
        pet.surprised()
        pet.setMood(.curious)
        pet.sparkle(count: 6)
        bubble?.dismiss()
        lastInteraction = Date()
        nextWanderAt = Date().addingTimeInterval(.random(in: 15...30))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.pet.setMood(.happy)
        }
    }

    // MARK: - Contextual speech

    private func greetByTimeOfDay() {
        guard !greeted else { return }
        greeted = true
        let h = Calendar.current.component(.hour, from: Date())
        let line: String
        let mood: Mood
        switch h {
        case 5..<11: line = "good morning ☀️"; mood = .happy
        case 11..<14: line = "lunch soon? 🍱"; mood = .happy
        case 14..<17: line = "afternoon ☕"; mood = .content
        case 17..<21: line = "evening, take it slow"; mood = .content
        case 21..<24: line = "winding down? 🌙"; mood = .sleepy
        default: line = "still up? 🌙"; mood = .sleepy
        }
        pet.setMood(mood)
        showBubble(line)
    }

    private func contextualNudge() {
        let idle = systemIdleSeconds()
        let session = Date().timeIntervalSince(sessionStart) / 60.0
        let line: String
        let mood: Mood
        if idle > 30 * 60 {
            line = "hey, still there? 👋"; mood = .curious
        } else if idle > 15 * 60 {
            line = "stretch break? 🧘"; mood = .content
        } else if session > 120 {
            line = "2hrs straight — water? 💧"; mood = .curious
        } else if session > 60 {
            line = "doing great ✨"; mood = .excited
            pet.sparkle(count: 14)
        } else {
            line = casualThoughts.randomElement() ?? "hi"; mood = .happy
        }
        pet.setMood(mood)
        showBubble(line)
    }

    private func systemIdleSeconds() -> TimeInterval {
        let any = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .init(rawValue: ~0)!)
        return any
    }

    // MARK: - Speech bubble

    private func showThought() {
        showBubble(casualThoughts.randomElement() ?? "hi")
    }

    private func showBubble(_ text: String) {
        bubble?.dismiss()
        guard let window = window else { return }
        let center = pet.screenCenter(in: window)
        bubble = SpeechBubble(text: text, anchor: CGPoint(x: center.x, y: center.y + 130))
        bubble?.show()
        voice.speak(text)
    }
}
