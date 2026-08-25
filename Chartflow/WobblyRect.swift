import SwiftUI

enum BoxMovementEffect: String, CaseIterable, Identifiable {
    case doodle
    case flow
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doodle:
            return "Doodle"
        case .flow:
            return "Flow"
        case .none:
            return "None"
        }
    }

    var description: String {
        switch self {
        case .doodle:
            return "Soft hand-drawn boxes."
        case .flow:
            return "Smooth drifting boxes."
        case .none:
            return "Still rounded boxes."
        }
    }
}

enum ChartflowBackgroundPattern: String, CaseIterable, Identifiable {
    case dots
    case squares
    case bigCircles
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dots:
            return "Dots"
        case .squares:
            return "Squares"
        case .bigCircles:
            return "Big Circles"
        case .none:
            return "None"
        }
    }
}

extension Color {
    static var chartflowBackground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
                : UIColor.white
        })
    }

    static var chartflowSurface: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)
                : UIColor.white
        })
    }

    static var chartflowText: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white
                : UIColor.black
        })
    }

    static var chartflowSecondaryText: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.72, alpha: 1)
                : UIColor.gray
        })
    }

    static var chartflowPattern: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.12)
                : UIColor(white: 0, alpha: 0.18)
        })
    }
}

struct AnyShape: Shape {
    private let makePath: @Sendable (CGRect) -> Path

    init<S: Shape & Sendable>(_ shape: S) {
        makePath = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        makePath(rect)
    }
}

struct WobblyRectangle: Shape {
    var cornerRadius: CGFloat = 16
    var wobble: CGFloat = 4
    var phase: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, min(w, h) / 2)

        func deterministicOffset(_ index: Int) -> CGFloat {
            let base = CGFloat(index) * 1.73
            return sin(base + phase) * wobble * 0.75 + cos(base * 0.57 + phase * 1.35) * wobble * 0.25
        }

        func jitter(_ point: CGPoint, index: Int) -> CGPoint {
            CGPoint(
                x: point.x + deterministicOffset(index),
                y: point.y + deterministicOffset(index + 100)
            )
        }

        let topLeftStart = jitter(CGPoint(x: r, y: 0), index: 1)
        let topRightStart = jitter(CGPoint(x: w - r, y: 0), index: 2)
        let topRightEnd = jitter(CGPoint(x: w, y: r), index: 3)
        let bottomRightStart = jitter(CGPoint(x: w, y: h - r), index: 4)
        let bottomRightEnd = jitter(CGPoint(x: w - r, y: h), index: 5)
        let bottomLeftStart = jitter(CGPoint(x: r, y: h), index: 6)
        let bottomLeftEnd = jitter(CGPoint(x: 0, y: h - r), index: 7)
        let topLeftEnd = jitter(CGPoint(x: 0, y: r), index: 8)

        path.move(to: topLeftStart)

        path.addLine(to: topRightStart)
        path.addQuadCurve(to: topRightEnd, control: jitter(CGPoint(x: w, y: 0), index: 9))

        path.addLine(to: bottomRightStart)
        path.addQuadCurve(to: bottomRightEnd, control: jitter(CGPoint(x: w, y: h), index: 10))

        path.addLine(to: bottomLeftStart)
        path.addQuadCurve(to: bottomLeftEnd, control: jitter(CGPoint(x: 0, y: h), index: 11))

        path.addLine(to: topLeftEnd)
        path.addQuadCurve(to: topLeftStart, control: jitter(CGPoint(x: 0, y: 0), index: 12))

        path.closeSubpath()

        return path
    }
}

struct DoodlyRectangle: Shape {
    var cornerRadius: CGFloat = 16
    var wobble: CGFloat = 4
    var seed: CGFloat = 0
    var pointsPerSide: Int = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let insetRect = rect.insetBy(dx: wobble + 1, dy: wobble + 1)
        let w = insetRect.width
        let h = insetRect.height
        let x = insetRect.minX
        let y = insetRect.minY
        let r = min(cornerRadius, min(w, h) / 2)
        let sidePoints = max(3, pointsPerSide)

        func noise(_ index: Int) -> CGFloat {
            let value = sin(CGFloat(index) * 12.9898 + seed * 78.233) * 43758.5453
            return value - floor(value)
        }

        func jitter(_ point: CGPoint, index: Int) -> CGPoint {
            CGPoint(
                x: point.x + (noise(index) * 2 - 1) * wobble,
                y: point.y + (noise(index + 200) * 2 - 1) * wobble
            )
        }

        var points: [CGPoint] = []

        for index in 0...sidePoints {
            let progress = CGFloat(index) / CGFloat(sidePoints)
            points.append(jitter(CGPoint(x: x + r + progress * (w - 2 * r), y: y), index: index))
        }

        for index in 1...sidePoints {
            let progress = CGFloat(index) / CGFloat(sidePoints)
            let angle = -.pi / 2 + progress * .pi / 2
            points.append(jitter(CGPoint(x: x + w - r + cos(angle) * r, y: y + r + sin(angle) * r), index: index + 20))
        }

        for index in 1...sidePoints {
            let progress = CGFloat(index) / CGFloat(sidePoints)
            points.append(jitter(CGPoint(x: x + w, y: y + r + progress * (h - 2 * r)), index: index + 40))
        }

        for index in 1...sidePoints {
            let progress = CGFloat(index) / CGFloat(sidePoints)
            let angle = progress * .pi / 2
            points.append(jitter(CGPoint(x: x + w - r + cos(angle) * r, y: y + h - r + sin(angle) * r), index: index + 60))
        }

        for index in 1...sidePoints {
            let progress = CGFloat(index) / CGFloat(sidePoints)
            points.append(jitter(CGPoint(x: x + w - r - progress * (w - 2 * r), y: y + h), index: index + 80))
        }

        for index in 1...sidePoints {
            let progress = CGFloat(index) / CGFloat(sidePoints)
            let angle = .pi / 2 + progress * .pi / 2
            points.append(jitter(CGPoint(x: x + r + cos(angle) * r, y: y + h - r + sin(angle) * r), index: index + 100))
        }

        for index in 1...sidePoints {
            let progress = CGFloat(index) / CGFloat(sidePoints)
            points.append(jitter(CGPoint(x: x, y: y + h - r - progress * (h - 2 * r)), index: index + 120))
        }

        for index in 1...sidePoints {
            let progress = CGFloat(index) / CGFloat(sidePoints)
            let angle = .pi + progress * .pi / 2
            points.append(jitter(CGPoint(x: x + r + cos(angle) * r, y: y + r + sin(angle) * r), index: index + 140))
        }

        guard let firstPoint = points.first, let lastPoint = points.last else {
            return path
        }

        func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
            CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        }

        path.move(to: midpoint(lastPoint, firstPoint))

        for index in points.indices {
            let currentPoint = points[index]
            let nextPoint = points[(index + 1) % points.count]
            path.addQuadCurve(to: midpoint(currentPoint, nextPoint), control: currentPoint)
        }

        path.closeSubpath()
        return path
    }
}

struct ChartflowBoxBackground: View {
    var cornerRadius: CGFloat = 16
    var wobble: CGFloat = 2
    var fillColor: Color
    var strokeColor: Color
    var lineWidth: CGFloat
    var inset: CGFloat = 1

    @AppStorage("boxMovementEffect") private var boxMovementEffectRaw = BoxMovementEffect.doodle.rawValue
    @AppStorage("reduceBoxMotion") private var reduceBoxMotion = false
    @AppStorage("highContrastBoxes") private var highContrastBoxes = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { timeline in
            let shape = currentShape(for: timeline.date)
            let effectiveStrokeColor = highContrastBoxes ? Color.chartflowText : strokeColor
            let effectiveLineWidth = highContrastBoxes ? max(lineWidth, 2.5) : lineWidth

            ZStack {
                shape
                    .fill(fillColor)
                    .padding(inset)
                shape
                    .stroke(effectiveStrokeColor, lineWidth: effectiveLineWidth)
                    .padding(inset)
            }
        }
    }

    private func currentShape(for date: Date) -> AnyShape {
        let effect = BoxMovementEffect(rawValue: boxMovementEffectRaw) ?? .doodle
        let motionIsReduced = reduceBoxMotion || systemReduceMotion
        let time = date.timeIntervalSinceReferenceDate

        switch effect {
        case .doodle:
            let phase = motionIsReduced ? 0 : CGFloat(Int(time * 7)) * 1.15
            return AnyShape(WobblyRectangle(cornerRadius: cornerRadius, wobble: wobble * 1.35, phase: phase))
        case .flow:
            let phase = motionIsReduced ? 0 : CGFloat(time * 2.2)
            return AnyShape(WobblyRectangle(cornerRadius: cornerRadius, wobble: wobble, phase: phase))
        case .none:
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

extension View {
    func chartflowBox(
        cornerRadius: CGFloat = 16,
        wobble: CGFloat = 2,
        fillColor: Color = .white,
        strokeColor: Color = .black,
        lineWidth: CGFloat = 2,
        inset: CGFloat = 1
    ) -> some View {
        background(
            ChartflowBoxBackground(
                cornerRadius: cornerRadius,
                wobble: wobble,
                fillColor: fillColor,
                strokeColor: strokeColor,
                lineWidth: lineWidth,
                inset: inset
            )
        )
    }
}

struct WobblyCircle: Shape {
    var wobble: CGFloat = 2
    var pointCount: Int = 24

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let points = (0..<pointCount).map { index in
            let angle = (CGFloat(index) / CGFloat(pointCount)) * 2 * .pi
            let value = sin(CGFloat(index) * 12.9898 + 78.233) * 43758.5453
            let fraction = value - floor(value)
            let jitteredRadius = radius + (fraction * 2 - 1) * wobble

            return CGPoint(
                x: center.x + cos(angle) * jitteredRadius,
                y: center.y + sin(angle) * jitteredRadius
            )
        }

        guard let firstPoint = points.first, let lastPoint = points.last else {
            return path
        }

        func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
            CGPoint(
                x: (first.x + second.x) / 2,
                y: (first.y + second.y) / 2
            )
        }

        path.move(to: midpoint(lastPoint, firstPoint))

        for index in points.indices {
            let currentPoint = points[index]
            let nextPoint = points[(index + 1) % points.count]
            path.addQuadCurve(to: midpoint(currentPoint, nextPoint), control: currentPoint)
        }

        path.closeSubpath()

        return path
    }
}
