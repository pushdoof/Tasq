import SwiftUI

/// Displays Tasq's hand-drawn replacement for an SF Symbol while keeping a
/// predictable point-size layout. Unknown names fall back to Apple's symbol.
struct TasqIcon: View {
    let systemName: String
    let size: CGFloat

    private let customDisplayScale: CGFloat = 1.5

    @AppStorage("boxMovementEffect") private var boxMovementEffectRaw = BoxMovementEffect.doodle.rawValue
    @AppStorage("reduceBoxMotion") private var reduceBoxMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.displayScale) private var displayScale

    init(_ systemName: String, size: CGFloat = 20) {
        self.systemName = systemName
        self.size = size
    }

    private var assetName: String {
        "TasqIcon-" + systemName.replacingOccurrences(of: ".", with: "-")
    }

    private var movementEffect: BoxMovementEffect {
        BoxMovementEffect(rawValue: boxMovementEffectRaw) ?? .doodle
    }

    private var motionIsReduced: Bool {
        reduceBoxMotion || systemReduceMotion
    }

    private var frameInterval: TimeInterval {
        switch movementEffect {
        case .doodle:
            return 1.0 / 7.0
        case .flow:
            return 1.0 / 10.0
        case .none:
            return 1
        }
    }

    private var animationSeed: Int {
        systemName.unicodeScalars.enumerated().reduce(0) { result, item in
            result + (item.offset + 1) * Int(item.element.value % 97)
        }
    }

    var body: some View {
        Group {
            if let replacement = UIImage(named: assetName) {
                TimelineView(
                    .animation(
                        minimumInterval: frameInterval,
                        paused: motionIsReduced || movementEffect == .none
                    )
                ) { timeline in
                    let displaySize = size * customDisplayScale
                    let frames = DoodlySpriteFrameCache.frames(
                        for: replacement,
                        named: assetName,
                        displaySize: displaySize,
                        displayScale: displayScale,
                        seed: animationSeed
                    )
                    let frame = displayedFrame(
                        from: frames,
                        fallback: replacement,
                        at: timeline.date
                    )

                    Image(uiImage: frame)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: displaySize,
                            height: displaySize
                        )
                }
            } else {
                Image(systemName: systemName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }

    private func displayedFrame(
        from frames: [UIImage],
        fallback: UIImage,
        at date: Date
    ) -> UIImage {
        guard !motionIsReduced, movementEffect != .none, !frames.isEmpty else {
            return fallback
        }

        let time = date.timeIntervalSinceReferenceDate
        let framesPerSecond: Double
        switch movementEffect {
        case .doodle:
            framesPerSecond = 7
        case .flow:
            framesPerSecond = 10
        case .none:
            return fallback
        }

        let offset = animationSeed % frames.count
        let tick = Int((time * framesPerSecond).rounded())
        let index = (tick + offset) % frames.count
        return frames[index]
    }
}

@MainActor
private enum DoodlySpriteFrameCache {
    private static let frameCount = 4
    private static var cachedFrames: [String: [UIImage]] = [:]

    static func frames(
        for image: UIImage,
        named name: String,
        displaySize: CGFloat,
        displayScale: CGFloat,
        seed: Int
    ) -> [UIImage] {
        let cacheKey = "\(name)-\(Int(displaySize * displayScale))"

        if let frames = cachedFrames[cacheKey] {
            return frames
        }

        let frames = makeFrames(
            from: image,
            displaySize: displaySize,
            displayScale: displayScale,
            seed: seed
        )
        cachedFrames[cacheKey] = frames
        return frames
    }

    private static func makeFrames(
        from image: UIImage,
        displaySize: CGFloat,
        displayScale: CGFloat,
        seed: Int
    ) -> [UIImage] {
        let canvasSize = CGSize(width: displaySize, height: displaySize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = displayScale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let baseImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: canvasSize))
        }
        let amplitude = min(max(displaySize * 0.018, 0.4), 0.85)

        return (0..<frameCount).map { frameIndex in
            let horizontallyWarped = renderer.image { rendererContext in
                let context = rendererContext.cgContext
                context.interpolationQuality = .high

                let stripHeight = max(1 / displayScale, displaySize / 30)
                var y: CGFloat = 0

                while y < displaySize {
                    let height = min(stripHeight, displaySize - y)
                    let progress = (y + height / 2) / displaySize
                    let xOffset = handDrawnOffset(
                        progress: progress,
                        seed: seed,
                        frame: frameIndex,
                        channel: 1
                    ) * amplitude

                    context.saveGState()
                    context.clip(to: CGRect(
                        x: 0,
                        y: y,
                        width: displaySize,
                        height: height + 0.5 / displayScale
                    ))
                    baseImage.draw(in: CGRect(
                        x: xOffset,
                        y: 0,
                        width: displaySize,
                        height: displaySize
                    ))
                    context.restoreGState()

                    y += height
                }
            }

            return renderer.image { rendererContext in
                let context = rendererContext.cgContext
                context.interpolationQuality = .high

                let stripWidth = max(1 / displayScale, displaySize / 30)
                var x: CGFloat = 0

                while x < displaySize {
                    let width = min(stripWidth, displaySize - x)
                    let progress = (x + width / 2) / displaySize
                    let yOffset = handDrawnOffset(
                        progress: progress,
                        seed: seed,
                        frame: frameIndex,
                        channel: 2
                    ) * amplitude

                    context.saveGState()
                    context.clip(to: CGRect(
                        x: x,
                        y: 0,
                        width: width + 0.5 / displayScale,
                        height: displaySize
                    ))
                    horizontallyWarped.draw(in: CGRect(
                        x: 0,
                        y: yOffset,
                        width: displaySize,
                        height: displaySize
                    ))
                    context.restoreGState()

                    x += width
                }
            }
        }
    }

    private static func handDrawnOffset(
        progress: CGFloat,
        seed: Int,
        frame: Int,
        channel: Int
    ) -> CGFloat {
        let controlPointCount = 6
        let clampedProgress = min(max(progress, 0), 1)
        let controlPosition = clampedProgress * CGFloat(controlPointCount - 1)
        let lowerIndex = Int(floor(controlPosition))
        let upperIndex = min(lowerIndex + 1, controlPointCount - 1)
        let fraction = controlPosition - CGFloat(lowerIndex)
        let smoothFraction = fraction * fraction * (3 - 2 * fraction)

        let lowerValue = controlPointNoise(
            seed: seed,
            frame: frame,
            controlPoint: lowerIndex,
            channel: channel
        )
        let upperValue = controlPointNoise(
            seed: seed,
            frame: frame,
            controlPoint: upperIndex,
            channel: channel
        )
        let interpolated = lowerValue + (upperValue - lowerValue) * smoothFraction
        let edgeSoftening = 0.4 + 0.6 * sin(clampedProgress * .pi)
        return interpolated * edgeSoftening
    }

    private static func controlPointNoise(
        seed: Int,
        frame: Int,
        controlPoint: Int,
        channel: Int
    ) -> CGFloat {
        let input = CGFloat(
            seed + frame * 997 + controlPoint * 83 + channel * 131
        ) * 0.071
        let value = sin(input) * 43_758.5453
        return (value - floor(value)) * 2 - 1
    }
}
