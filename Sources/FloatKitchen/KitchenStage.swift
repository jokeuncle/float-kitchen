import AppKit
import QuartzCore
import KitchenCore

/// A layer-hosting view. AppKit never paints a partial backing-store update
/// over the animated subtree. Information signs are a separate sibling NSView.
final class KitchenStage: NSView {
    override var isFlipped: Bool { true }
    private let scene = CALayer()
    private let environment = CALayer()
    private let foreground = CALayer()
    private let troupe = CALayer()
    private var chefs: [CALayer] = []
    private var smoke: [CAEmitterLayer] = []
    private var rings: [CAShapeLayer] = []
    private var poses: [CGImage] = []
    private var lastStates: [KitchenActivity] = []
    private var asleep = false
    private var lastReduced = false
    var onSelect: ((Int) -> Void)?
    var reducedMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    override init(frame: NSRect) {
        super.init(frame: frame)
        scene.isGeometryFlipped = true; scene.masksToBounds = true; scene.cornerRadius = 16
        layer = scene; wantsLayer = true
        layerContentsRedrawPolicy = .never
        let kitchen = Self.load("kitchen")
        if let atlas = Self.load("chef-states") {
            for index in 0..<8 {
                let rect = CGRect(x: CGFloat(index%4)*CGFloat(atlas.width)/4, y: CGFloat(index/4)*CGFloat(atlas.height)/2, width: CGFloat(atlas.width)/4, height: CGFloat(atlas.height)/2).integral
                if let crop = atlas.cropping(to: rect) { poses.append(crop) }
            }
        }
        environment.contents = kitchen; environment.contentsGravity = .resize
        scene.addSublayer(environment); scene.addSublayer(troupe)
        for _ in 0..<3 {
            let chef = CALayer(); chef.contentsGravity = .resize
            chef.anchorPoint = CGPoint(x: 0.5, y: 0.9)
            chef.minificationFilter = .trilinear; chef.magnificationFilter = .linear
            troupe.addSublayer(chef); chefs.append(chef)
        }
        foreground.contents = kitchen; foreground.contentsGravity = .resize
        foreground.contentsRect = CGRect(x: 0, y: 0.68, width: 1, height: 0.32)
        scene.addSublayer(foreground)
        for _ in 0..<3 {
            let emitter = CAEmitterLayer(); emitter.emitterShape = .line; emitter.emitterSize = CGSize(width: 9, height: 1)
            emitter.renderMode = .unordered; scene.addSublayer(emitter); smoke.append(emitter)
            let ring = CAShapeLayer(); ring.fillColor = NSColor.clear.cgColor; ring.strokeColor = Bistro.gold.cgColor
            ring.lineWidth = 1; ring.opacity = 0; scene.addSublayer(ring); rings.append(ring)
        }
        setAccessibilityElement(true); setAccessibilityRole(.image)
        setAccessibilityLabel("微缩厨房，三位机器人厨师分别代表 Codex、Claude 和自定义事件")
    }
    required init?(coder: NSCoder) { fatalError() }
    static func load(_ name: String) -> CGImage? {
        let resource = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Assets")
            ?? Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Assets")
        guard let url = resource, let image = NSImage(contentsOf: url) else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        scene.bounds = bounds; environment.frame = bounds; troupe.frame = bounds
        for (i, chef) in chefs.enumerated() {
            let x = bounds.width * [0.31, 0.53, 0.75][i]
            chef.bounds = CGRect(x: 0, y: 0, width: bounds.width*0.235, height: bounds.height*0.47)
            chef.position = CGPoint(x: x, y: bounds.height*0.73)
            smoke[i].emitterPosition = CGPoint(x: x+bounds.width*0.028, y: bounds.height*0.57)
            rings[i].frame = CGRect(x: x-11, y: bounds.height*0.59-11, width: 22, height: 22)
            rings[i].path = CGPath(ellipseIn: CGRect(x: 2, y: 2, width: 18, height: 18), transform: nil)
        }
        foreground.frame = CGRect(x: 0, y: bounds.height*0.68, width: bounds.width, height: bounds.height*0.32)
        CATransaction.commit()
    }
    func setStates(_ states: [KitchenActivity], paused: Bool) {
        guard states.count == 3, states != lastStates || paused != asleep || reducedMotion != lastReduced else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        let previous = lastStates
        let playbackChanged = paused != asleep || reducedMotion != lastReduced
        lastStates = states; asleep = paused; lastReduced = reducedMotion
        for (i, chef) in chefs.enumerated() {
            let activity = states[i]
            let poseChanged = previous.indices.contains(i) && previous[i] != activity
            if previous.indices.contains(i), !poseChanged, !playbackChanged { continue }
            let oldTransform = chef.presentation()?.transform ?? CATransform3DIdentity
            chef.removeAllAnimations(); rings[i].removeAllAnimations(); rings[i].opacity = 0; smoke[i].emitterCells = []
            let blend = poseChanged && !reducedMotion && !paused
            if blend {
                let fade = CATransition(); fade.type = .fade; fade.duration = 0.36
                fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                chef.add(fade, forKey: "pose-fade")
                let settle = CABasicAnimation(keyPath: "transform")
                settle.fromValue = NSValue(caTransform3D: oldTransform); settle.toValue = NSValue(caTransform3D: CATransform3DIdentity)
                settle.duration = 0.28; settle.timingFunction = CAMediaTimingFunction(name: .easeOut)
                chef.add(settle, forKey: "settle")
            }
            if poses.count == 8 { chef.contents = poses[activity.atlasIndex] }
            guard !paused, !reducedMotion, activity != .idle else { continue }
            let action = CAKeyframeAnimation()
            switch activity {
            case .reading:
                action.keyPath = "transform.rotation.z"; action.values = [0, -0.018, 0.018, 0]; action.duration = 2.8
            case .searching:
                action.keyPath = "transform.translation.x"; action.values = [0, -18, 0, 0]; action.keyTimes = [0, 0.35, 0.75, 1]; action.duration = 4.2
            case .cooking:
                action.keyPath = "transform.rotation.z"; action.values = [0, -0.075, 0.08, 0]; action.duration = 1.2
            case .testing:
                action.keyPath = "transform.translation.y"; action.values = [0, -1.8, 0, -1, 0]; action.duration = 0.45
            case .waiting:
                action.keyPath = "transform.rotation.z"; action.values = [0, -0.025, 0.025, 0, 0]; action.duration = 1.7
                let scale = CABasicAnimation(keyPath: "transform.scale"); scale.fromValue = 0.5; scale.toValue = 1.6; scale.duration = 1.7; scale.repeatCount = .infinity
                let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 0.65; fade.toValue = 0; fade.duration = 1.7; fade.repeatCount = .infinity
                rings[i].add(scale, forKey: "bell-ring"); rings[i].add(fade, forKey: "bell-fade")
            case .failed:
                action.keyPath = "transform.rotation.z"; action.values = [0, -0.018, 0.018, 0]; action.duration = 2
            case .served:
                action.keyPath = "transform.translation.y"; action.values = [0, -8, 0, 0]; action.keyTimes = [0, 0.3, 0.6, 1]; action.duration = 3.6
            case .idle: continue
            }
            action.repeatCount = .infinity; action.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            if blend { action.beginTime = CACurrentMediaTime()+0.28 }
            chef.add(action, forKey: "activity")
            if activity == .cooking || activity == .served {
                let bob = CAKeyframeAnimation(keyPath: "transform.translation.y")
                bob.values = [0, -4, 0]; bob.duration = 1.2; bob.repeatCount = .infinity; bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                // Served already uses translation.y; avoid two animations fighting.
                if activity == .cooking { chef.add(bob, forKey: "pan-toss") }
            }
            if activity == .failed || activity == .testing || activity == .cooking {
                let cell = CAEmitterCell(); cell.contents = Self.puff
                cell.birthRate = activity == .failed ? 5 : 2; cell.lifetime = 1.6
                cell.velocity = 13; cell.velocityRange = 4; cell.emissionLongitude = -.pi/2; cell.emissionRange = 0.4
                cell.scale = activity == .failed ? 0.35 : 0.18; cell.scaleSpeed = 0.1; cell.alphaSpeed = -0.5
                cell.color = (activity == .failed ? Bistro.ink : Bistro.cream).withAlphaComponent(activity == .failed ? 0.8 : 0.5).cgColor
                smoke[i].emitterCells = [cell]
            }
        }
        setAccessibilityValue(states.enumerated().map { "\(["Codex", "Claude", "自定义"][$0.offset])：\($0.element.meaning)" }.joined(separator: "；"))
    }
    private static let puff: CGImage? = {
        let image = NSImage(size: NSSize(width: 32, height: 32)); image.lockFocus()
        NSGradient(starting: NSColor.white.withAlphaComponent(0.8), ending: NSColor.white.withAlphaComponent(0))?.draw(in: NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: 32, height: 32)), relativeCenterPosition: .zero)
        image.unlockFocus(); var rect = CGRect(x: 0, y: 0, width: 32, height: 32)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }()
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.y > bounds.height*0.3, point.y < bounds.height*0.97 {
            onSelect?(min(2, max(0, Int((point.x/bounds.width-0.2)/0.22))))
        } else { window?.performDrag(with: event) }
    }
}
