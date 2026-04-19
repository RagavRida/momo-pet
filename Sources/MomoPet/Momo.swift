import AppKit
import SceneKit

enum Mood {
    case happy, curious, sleepy, excited, content, surprised, sad, angry
}

/// Procedural lavender blob mascot built from SceneKit primitives.
final class Momo {
    let node = SCNNode()
    private let body = SCNNode()
    private let glow = SCNNode()
    private let leftEye = SCNNode()
    private let rightEye = SCNNode()
    private let leftPupil = SCNNode()
    private let rightPupil = SCNNode()
    private let leftLid = SCNNode()
    private let rightLid = SCNNode()
    private let leftArm = SCNNode()
    private let rightArm = SCNNode()
    private let mouth = SCNNode()
    private let leftCheek = SCNNode()
    private let rightCheek = SCNNode()
    private let sparkleAnchor = SCNNode()

    /// Logical screen-space radius (matches camera ortho scale).
    let radius: CGFloat = 90

    private var bodyMaterial: SCNMaterial!
    private var lidMaterials: [SCNMaterial] = []
    private(set) var mood: Mood = .happy

    init() {
        buildBody()
        buildGlow()
        buildEyes()
        buildArms()
        buildMouth()
        buildCheeks()
        node.addChildNode(sparkleAnchor)
        setMood(.happy)
    }

    // MARK: - Construction

    private func buildBody() {
        let sphere = SCNSphere(radius: 90)
        sphere.segmentCount = 64
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(calibratedRed: 0.72, green: 0.65, blue: 0.85, alpha: 1.0)
        mat.specular.contents = NSColor(white: 1.0, alpha: 0.6)
        mat.shininess = 0.4
        mat.lightingModel = .blinn
        sphere.materials = [mat]
        bodyMaterial = mat
        body.geometry = sphere
        node.addChildNode(body)
    }

    private func buildGlow() {
        let plane = SCNPlane(width: 220, height: 60)
        let mat = SCNMaterial()
        mat.diffuse.contents = radialGradient()
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.transparencyMode = .aOne
        plane.materials = [mat]
        glow.geometry = plane
        glow.position = SCNVector3(0, -85, -10)
        glow.opacity = 0.45
        node.addChildNode(glow)
    }

    private func radialGradient() -> NSImage {
        let size = NSSize(width: 256, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            let colors = [
                NSColor(white: 0, alpha: 0.5).cgColor,
                NSColor(white: 0, alpha: 0).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
            ctx.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 128, y: 32), startRadius: 4,
                endCenter: CGPoint(x: 128, y: 32), endRadius: 110,
                options: []
            )
        }
        image.unlockFocus()
        return image
    }

    private func buildEyes() {
        configureEye(socket: leftEye, pupil: leftPupil, lid: leftLid, x: -32)
        configureEye(socket: rightEye, pupil: rightPupil, lid: rightLid, x: 32)
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
    }

    private func configureEye(socket: SCNNode, pupil: SCNNode, lid: SCNNode, x: Float) {
        let white = SCNSphere(radius: 22)
        let whiteMat = SCNMaterial()
        whiteMat.diffuse.contents = NSColor.white
        whiteMat.lightingModel = .constant
        white.materials = [whiteMat]
        socket.geometry = white
        socket.position = SCNVector3(x, 22, 78)

        let pupilGeo = SCNSphere(radius: 11)
        let pupilMat = SCNMaterial()
        pupilMat.diffuse.contents = NSColor(white: 0.05, alpha: 1.0)
        pupilMat.lightingModel = .constant
        pupilGeo.materials = [pupilMat]
        pupil.geometry = pupilGeo
        pupil.position = SCNVector3(0, 0, 14)
        socket.addChildNode(pupil)

        // Tiny shine highlight
        let shine = SCNNode()
        let shineGeo = SCNSphere(radius: 3)
        let shineMat = SCNMaterial()
        shineMat.diffuse.contents = NSColor.white
        shineMat.lightingModel = .constant
        shineGeo.materials = [shineMat]
        shine.geometry = shineGeo
        shine.position = SCNVector3(-3, 4, 10)
        pupil.addChildNode(shine)

        // Eyelid: scales vertically to "close" the eye
        let lidGeo = SCNSphere(radius: 22.5)
        let lidMat = SCNMaterial()
        lidMat.diffuse.contents = NSColor(calibratedRed: 0.72, green: 0.65, blue: 0.85, alpha: 1.0)
        lidMat.lightingModel = .constant
        lidGeo.materials = [lidMat]
        lid.geometry = lidGeo
        lid.scale = SCNVector3(1.0, 0.0, 1.0)
        lidMaterials.append(lidMat)
        socket.addChildNode(lid)
    }

    private func buildArms() {
        configureArm(arm: leftArm, x: -82)
        configureArm(arm: rightArm, x: 82)
        node.addChildNode(leftArm)
        node.addChildNode(rightArm)
    }

    private func configureArm(arm: SCNNode, x: Float) {
        let capsule = SCNCapsule(capRadius: 10, height: 30)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(calibratedRed: 0.66, green: 0.58, blue: 0.80, alpha: 1.0)
        mat.lightingModel = .blinn
        capsule.materials = [mat]
        arm.geometry = capsule
        arm.position = SCNVector3(x, -10, 30)
        arm.eulerAngles = SCNVector3(0, 0, x > 0 ? -Float.pi/3 : Float.pi/3)
    }

    private func buildMouth() {
        let geo = SCNTorus(ringRadius: 12, pipeRadius: 2.2)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(white: 0.1, alpha: 1.0)
        mat.lightingModel = .constant
        geo.materials = [mat]
        mouth.geometry = geo
        // Show only the bottom half of the torus → smile arc
        mouth.position = SCNVector3(0, -8, 86)
        mouth.eulerAngles = SCNVector3(Float.pi/2, 0, 0)
        mouth.scale = SCNVector3(1.0, 0.55, 1.0)
        node.addChildNode(mouth)
    }

    private func buildCheeks() {
        configureCheek(cheek: leftCheek, x: -50)
        configureCheek(cheek: rightCheek, x: 50)
        node.addChildNode(leftCheek)
        node.addChildNode(rightCheek)
    }

    private func configureCheek(cheek: SCNNode, x: Float) {
        let geo = SCNSphere(radius: 9)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(calibratedRed: 1.0, green: 0.6, blue: 0.7, alpha: 0.55)
        mat.lightingModel = .constant
        mat.transparencyMode = .aOne
        geo.materials = [mat]
        cheek.geometry = geo
        cheek.position = SCNVector3(x, -2, 76)
        cheek.opacity = 0.0
    }

    // MARK: - Mood

    func setMood(_ m: Mood) {
        mood = m
        let bodyColor: NSColor
        let cheekAlpha: CGFloat
        var cheekColor: NSColor = NSColor(calibratedRed: 1.0, green: 0.6, blue: 0.7, alpha: 0.9)
        var lidClose: CGFloat = 0.0  // 0 = open, 1 = closed; partial = squint
        switch m {
        case .happy:
            bodyColor = NSColor(calibratedRed: 0.74, green: 0.66, blue: 0.88, alpha: 1.0)
            cheekAlpha = 0.7
            smile()
        case .curious:
            bodyColor = NSColor(calibratedRed: 0.70, green: 0.74, blue: 0.92, alpha: 1.0)
            cheekAlpha = 0.4
            mouthShape(width: 0.5, height: 0.5)
        case .sleepy:
            bodyColor = NSColor(calibratedRed: 0.62, green: 0.58, blue: 0.78, alpha: 1.0)
            cheekAlpha = 0.3
            mouthShape(width: 0.4, height: 0.2)
        case .excited:
            bodyColor = NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.92, alpha: 1.0)
            cheekAlpha = 0.95
            bigSmile()
        case .content:
            bodyColor = NSColor(calibratedRed: 0.72, green: 0.65, blue: 0.85, alpha: 1.0)
            cheekAlpha = 0.6
            smile()
        case .surprised:
            bodyColor = NSColor(calibratedRed: 0.85, green: 0.78, blue: 0.95, alpha: 1.0)
            cheekAlpha = 0.5
            mouthShape(width: 0.6, height: 0.9)
        case .sad:
            bodyColor = NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.72, alpha: 1.0)
            cheekAlpha = 0.2
            frown()
        case .angry:
            bodyColor = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.55, alpha: 1.0)
            cheekColor = NSColor(calibratedRed: 0.95, green: 0.15, blue: 0.15, alpha: 1.0)
            cheekAlpha = 0.95
            lidClose = 0.5  // narrowed eyes
            frown()
            shake()
            steamPuff()
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        bodyMaterial.diffuse.contents = bodyColor
        for lm in lidMaterials { lm.diffuse.contents = bodyColor }
        let cheekMat = leftCheek.geometry?.firstMaterial
        cheekMat?.diffuse.contents = cheekColor
        rightCheek.geometry?.firstMaterial?.diffuse.contents = cheekColor
        leftCheek.opacity = cheekAlpha
        rightCheek.opacity = cheekAlpha
        // squint via partial lid close
        leftLid.scale = SCNVector3(1.0, lidClose, 1.0)
        rightLid.scale = SCNVector3(1.0, lidClose, 1.0)
        SCNTransaction.commit()
    }

    private func shake() {
        let l = SCNAction.moveBy(x: -6, y: 0, z: 0, duration: 0.06)
        let r = SCNAction.moveBy(x: 12, y: 0, z: 0, duration: 0.06)
        let back = SCNAction.moveBy(x: -6, y: 0, z: 0, duration: 0.06)
        body.runAction(.repeat(.sequence([l, r, back]), count: 3))
    }

    private func steamPuff() {
        for i in 0..<2 {
            let s = SCNNode()
            let geo = SCNSphere(radius: 6)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(white: 1.0, alpha: 0.7)
            mat.lightingModel = .constant
            geo.materials = [mat]
            s.geometry = geo
            s.position = SCNVector3(CGFloat(i == 0 ? -45 : 45), 80, 80)
            sparkleAnchor.addChildNode(s)
            let move = SCNAction.move(by: SCNVector3(0, 60, 0), duration: 0.8)
            move.timingMode = .easeOut
            let scale = SCNAction.scale(to: 2.5, duration: 0.8)
            let fade = SCNAction.fadeOut(duration: 0.8)
            s.runAction(.group([move, scale, fade])) { s.removeFromParentNode() }
        }
    }

    private func smile() {
        animateScale(mouth, to: SCNVector3(1.0, 0.55, 1.0), duration: 0.25)
        rotateMouth(.pi/2)
    }

    private func bigSmile() {
        animateScale(mouth, to: SCNVector3(1.3, 0.7, 1.0), duration: 0.25)
        rotateMouth(.pi/2)
    }

    private func frown() {
        animateScale(mouth, to: SCNVector3(1.0, 0.55, 1.0), duration: 0.25)
        rotateMouth(-.pi/2)
    }

    private func mouthShape(width: Float, height: Float) {
        animateScale(mouth, to: SCNVector3(width, height, 1.0), duration: 0.25)
    }

    private func rotateMouth(_ angle: Float) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.25
        mouth.eulerAngles = SCNVector3(angle, 0, 0)
        SCNTransaction.commit()
    }

    // MARK: - Animation API

    func breathe() {
        let up = SCNAction.scale(to: 1.03, duration: 1.4)
        up.timingMode = .easeInEaseOut
        let down = SCNAction.scale(to: 0.98, duration: 1.4)
        down.timingMode = .easeInEaseOut
        body.runAction(.repeatForever(.sequence([up, down])), forKey: "breathe")
    }

    func blink() {
        animateScale(leftLid, to: SCNVector3(1.0, 1.0, 1.0), duration: 0.07) { [weak self] in
            self?.animateScale(self!.leftLid, to: SCNVector3(1.0, 0.0, 1.0), duration: 0.07)
        }
        animateScale(rightLid, to: SCNVector3(1.0, 1.0, 1.0), duration: 0.07) { [weak self] in
            self?.animateScale(self!.rightLid, to: SCNVector3(1.0, 0.0, 1.0), duration: 0.07)
        }
    }

    /// Soft close (sleep)
    func closeEyes() {
        animateScale(leftLid, to: SCNVector3(1.0, 0.85, 1.0), duration: 0.4)
        animateScale(rightLid, to: SCNVector3(1.0, 0.85, 1.0), duration: 0.4)
    }

    func openEyes() {
        animateScale(leftLid, to: SCNVector3(1.0, 0.0, 1.0), duration: 0.3)
        animateScale(rightLid, to: SCNVector3(1.0, 0.0, 1.0), duration: 0.3)
    }

    private func animateScale(_ node: SCNNode, to target: SCNVector3, duration: TimeInterval, completion: (() -> Void)? = nil) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.completionBlock = completion
        node.scale = target
        SCNTransaction.commit()
    }

    /// Move pupils toward a normalized direction (-1...1).
    func lookAt(direction: CGPoint) {
        let dx = max(-1, min(1, Float(direction.x))) * 6
        let dy = max(-1, min(1, Float(direction.y))) * 5
        leftPupil.position = SCNVector3(dx, dy, 14)
        rightPupil.position = SCNVector3(dx, dy, 14)
    }

    func surprised() {
        let up = SCNAction.scale(to: 1.25, duration: 0.08)
        let down = SCNAction.scale(to: 1.0, duration: 0.18)
        leftEye.runAction(.sequence([up, down]))
        rightEye.runAction(.sequence([up, down]))
    }

    func hop() {
        let up = SCNAction.moveBy(x: 0, y: 60, z: 0, duration: 0.18)
        up.timingMode = .easeOut
        let down = SCNAction.moveBy(x: 0, y: -60, z: 0, duration: 0.22)
        down.timingMode = .easeIn
        node.runAction(.sequence([up, down]))
        animateScale(body, to: SCNVector3(1.15, 0.85, 1.0), duration: 0.1) { [weak self] in
            self?.animateScale(self!.body, to: SCNVector3(1.0, 1.0, 1.0), duration: 0.15)
        }
    }

    func squish(intensity: Float = 0.85) {
        let stretch = Float(2.0) - intensity
        animateScale(body, to: SCNVector3(stretch, intensity, 1.0), duration: 0.1) { [weak self] in
            guard let self = self else { return }
            self.animateScale(self.body, to: SCNVector3(1.0, 1.0, 1.0), duration: 0.18)
        }
    }

    func wiggleArms() {
        let l = SCNAction.rotateBy(x: 0, y: 0, z: 0.4, duration: 0.15)
        let r = l.reversed()
        leftArm.runAction(.repeat(.sequence([l, r, r, l]), count: 1))
        rightArm.runAction(.repeat(.sequence([r, l, l, r]), count: 1))
    }

    private var savedMouthScale: SCNVector3?

    /// Start chattering mouth animation (loop until stopTalking).
    func startTalking() {
        if savedMouthScale == nil { savedMouthScale = mouth.scale }
        mouth.removeAllActions()
        let openAction = SCNAction.customAction(duration: 0.12) { [weak self] _, _ in
            guard let self = self else { return }
            self.mouth.scale = SCNVector3(0.85, 0.95, 1.0)
        }
        let closeAction = SCNAction.customAction(duration: 0.12) { [weak self] _, _ in
            guard let self = self else { return }
            self.mouth.scale = SCNVector3(0.7, 0.35, 1.0)
        }
        mouth.runAction(.repeatForever(.sequence([openAction, closeAction])), forKey: "talk")
    }

    func stopTalking() {
        mouth.removeAction(forKey: "talk")
        if let saved = savedMouthScale {
            animateScale(mouth, to: saved, duration: 0.15)
        }
    }

    func sparkle(count: Int = 8) {
        for _ in 0..<count {
            let s = SCNNode()
            let geo = SCNSphere(radius: CGFloat.random(in: 1.5...3.0))
            let mat = SCNMaterial()
            mat.diffuse.contents = [NSColor.white, NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.6, alpha: 1.0), NSColor(calibratedRed: 0.85, green: 0.8, blue: 1.0, alpha: 1.0)].randomElement()!
            mat.lightingModel = .constant
            geo.materials = [mat]
            s.geometry = geo
            let angle = Float.random(in: 0..<(2 * .pi))
            let dist: Float = 100
            let tx = CGFloat(cos(angle) * dist)
            let ty = CGFloat(sin(angle) * dist + 30)
            s.position = SCNVector3(0, 30, 100)
            sparkleAnchor.addChildNode(s)
            let move = SCNAction.move(by: SCNVector3(tx, ty, 0), duration: 0.7)
            move.timingMode = .easeOut
            let fade = SCNAction.fadeOut(duration: 0.7)
            s.runAction(.group([move, fade])) {
                s.removeFromParentNode()
            }
        }
    }

    func screenCenter(in window: NSWindow) -> CGPoint {
        let p = node.presentation.position
        let center = CGPoint(x: window.frame.width/2, y: window.frame.height/2)
        return CGPoint(x: window.frame.origin.x + center.x + CGFloat(p.x),
                       y: window.frame.origin.y + center.y + CGFloat(p.y))
    }
}
