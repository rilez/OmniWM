import AppKit
import QuartzCore

final class BorderWindow: NSWindow {
    private let borderLayer: CAShapeLayer
    private var config: BorderConfig
    private var currentCornerRadius: CGFloat = 9
    private var snakeLayer1: CAShapeLayer?
    private var snakeLayer2: CAShapeLayer?
    private var effectRunning = false

    init(config: BorderConfig) {
        self.config = config
        borderLayer = CAShapeLayer()

        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupLayer()
    }

    private func setupWindow() {
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        ignoresMouseEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        contentView?.wantsLayer = true
        contentView?.layer?.addSublayer(borderLayer)
    }

    private func setupLayer() {
        borderLayer.fillColor = nil
        borderLayer.strokeColor = config.color.cgColor
        borderLayer.lineWidth = config.width
    }

    private var wid: UInt32 { UInt32(windowNumber) }

    func update(frame targetFrame: CGRect, cornerRadius: CGFloat, config: BorderConfig, targetWid: UInt32? = nil) {
        self.config = config
        currentCornerRadius = cornerRadius

        let expansion = config.width / 2
        let borderFrame = targetFrame.insetBy(dx: -expansion, dy: -expansion)

        SkyLight.shared.disableUpdates()
        defer { SkyLight.shared.reenableUpdates() }

        setFrame(borderFrame, display: false)

        borderLayer.frame = CGRect(origin: .zero, size: borderFrame.size)
        borderLayer.strokeColor = config.color.cgColor
        borderLayer.lineWidth = config.width

        let pathRect = CGRect(origin: .zero, size: borderFrame.size).insetBy(
            dx: config.width / 2,
            dy: config.width / 2
        )

        let adjustedRadius = max(0, cornerRadius + config.width / 2)
        let path = CGPath(
            roundedRect: pathRect,
            cornerWidth: adjustedRadius,
            cornerHeight: adjustedRadius,
            transform: nil
        )
        borderLayer.path = path

        if let targetWid {
            SkyLight.shared.orderWindow(wid, relativeTo: targetWid, order: .below)
        }
    }

    func updateConfig(_ config: BorderConfig) {
        let effectChanged = self.config.effectType != config.effectType ||
            self.config.pulseSpeed != config.pulseSpeed ||
            self.config.snakeSpeed != config.snakeSpeed ||
            self.config.snakeSecondaryColor != config.snakeSecondaryColor ||
            self.config.color != config.color

        self.config = config
        borderLayer.strokeColor = config.color.cgColor
        borderLayer.lineWidth = config.width

        if frame.size != .zero {
            let windowBounds = CGRect(origin: .zero, size: frame.size)
            let pathRect = windowBounds.insetBy(dx: config.width / 2, dy: config.width / 2)
            let adjustedRadius = max(0, currentCornerRadius + config.width / 2)
            let path = CGPath(
                roundedRect: pathRect,
                cornerWidth: adjustedRadius,
                cornerHeight: adjustedRadius,
                transform: nil
            )
            borderLayer.path = path
            updateSnakePaths(path)
        }

        if effectChanged {
            stopEffect()
            startEffect()
        }
    }

    func startEffect() {
        guard !effectRunning else { return }
        effectRunning = true

        switch config.effectType {
        case .none:
            borderLayer.isHidden = false
            stopEffect()
        case .pulse:
            borderLayer.isHidden = false
            startPulseAnimation()
        case .snake:
            borderLayer.isHidden = true
            setupSnakeLayers()
            startSnakeAnimation()
        }
    }

    func stopEffect() {
        effectRunning = false
        borderLayer.removeAllAnimations()
        borderLayer.opacity = 1.0
        borderLayer.strokeColor = config.color.cgColor

        snakeLayer1?.removeAllAnimations()
        snakeLayer1?.removeFromSuperlayer()
        snakeLayer1 = nil

        snakeLayer2?.removeAllAnimations()
        snakeLayer2?.removeFromSuperlayer()
        snakeLayer2 = nil
    }

    private func startPulseAnimation() {
        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 1.0
        opacityAnim.toValue = 0.4
        opacityAnim.duration = 1.0 / Double(config.pulseSpeed)
        opacityAnim.autoreverses = true
        opacityAnim.repeatCount = .infinity
        opacityAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let brightenedColor = brightenColor(config.color)
        let colorAnim = CABasicAnimation(keyPath: "strokeColor")
        colorAnim.fromValue = config.color.cgColor
        colorAnim.toValue = brightenedColor.cgColor
        colorAnim.duration = 1.0 / Double(config.pulseSpeed)
        colorAnim.autoreverses = true
        colorAnim.repeatCount = .infinity
        colorAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        borderLayer.add(opacityAnim, forKey: "pulseOpacity")
        borderLayer.add(colorAnim, forKey: "pulseBrightness")
    }

    private func brightenColor(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return color }
        return NSColor(
            hue: rgb.hueComponent,
            saturation: max(0, rgb.saturationComponent - 0.2),
            brightness: min(1.0, rgb.brightnessComponent + 0.3),
            alpha: rgb.alphaComponent
        )
    }

    private func setupSnakeLayers() {
        snakeLayer1?.removeFromSuperlayer()
        snakeLayer2?.removeFromSuperlayer()

        guard let path = borderLayer.path else { return }
        let perimeter = calculatePerimeter()

        let layer1 = CAShapeLayer()
        layer1.path = path
        layer1.fillColor = nil
        layer1.strokeColor = config.color.cgColor
        layer1.lineWidth = config.width
        layer1.lineDashPattern = [NSNumber(value: perimeter / 2), NSNumber(value: perimeter / 2)]
        layer1.frame = CGRect(origin: .zero, size: frame.size)

        let layer2 = CAShapeLayer()
        layer2.path = path
        layer2.fillColor = nil
        layer2.strokeColor = config.snakeSecondaryColor.cgColor
        layer2.lineWidth = config.width
        layer2.lineDashPattern = [NSNumber(value: perimeter / 2), NSNumber(value: perimeter / 2)]
        layer2.lineDashPhase = CGFloat(perimeter / 2)
        layer2.frame = CGRect(origin: .zero, size: frame.size)

        contentView?.layer?.addSublayer(layer1)
        contentView?.layer?.addSublayer(layer2)

        snakeLayer1 = layer1
        snakeLayer2 = layer2
    }

    private func calculatePerimeter() -> Double {
        let rect = CGRect(origin: .zero, size: frame.size).insetBy(
            dx: config.width / 2, dy: config.width / 2
        )
        let adjustedRadius = max(0, currentCornerRadius + config.width / 2)
        let straightParts = 2 * (rect.width - 2 * adjustedRadius) + 2 * (rect.height - 2 * adjustedRadius)
        let cornerParts = 2 * .pi * adjustedRadius
        return Double(max(straightParts + cornerParts, 1))
    }

    private func updateSnakePaths(_ path: CGPath) {
        guard snakeLayer1 != nil else { return }
        let perimeter = calculatePerimeter()

        snakeLayer1?.path = path
        snakeLayer1?.lineDashPattern = [NSNumber(value: perimeter / 2), NSNumber(value: perimeter / 2)]
        snakeLayer1?.frame = CGRect(origin: .zero, size: frame.size)

        snakeLayer2?.path = path
        snakeLayer2?.lineDashPattern = [NSNumber(value: perimeter / 2), NSNumber(value: perimeter / 2)]
        snakeLayer2?.frame = CGRect(origin: .zero, size: frame.size)
    }

    private func startSnakeAnimation() {
        let perimeter = calculatePerimeter()
        let duration = 1.0 / Double(config.snakeSpeed)

        let anim1 = CABasicAnimation(keyPath: "lineDashPhase")
        anim1.fromValue = 0
        anim1.toValue = perimeter
        anim1.duration = duration
        anim1.repeatCount = .infinity
        anim1.timingFunction = CAMediaTimingFunction(name: .linear)

        let anim2 = CABasicAnimation(keyPath: "lineDashPhase")
        anim2.fromValue = perimeter / 2
        anim2.toValue = perimeter / 2 + perimeter
        anim2.duration = duration
        anim2.repeatCount = .infinity
        anim2.timingFunction = CAMediaTimingFunction(name: .linear)

        snakeLayer1?.add(anim1, forKey: "snakePhase")
        snakeLayer2?.add(anim2, forKey: "snakePhase")
    }
}
