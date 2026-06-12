import SwiftUI

// MARK: - Movement Effect

enum BoxMovementEffect: String, CaseIterable, Identifiable {
    case random
    case flow
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .random:
            return "Random"
        case .flow:
            return "Flow"
        case .none:
            return "None"
        }
    }
}

// MARK: - Animated Background

struct WobblyBoxBackground: View {
    var fillColor: Color
    var strokeColor: Color
    var lineWidth: CGFloat
    var cornerRadius: CGFloat = 16
    var wobble: CGFloat = 2

    @AppStorage("boxMovementEffect")
    private var effectRawValue = BoxMovementEffect.random.rawValue

    private var effect: BoxMovementEffect {
        BoxMovementEffect(rawValue: effectRawValue) ?? .random
    }

    var body: some View {
        switch effect {

        case .random:
            TimelineView(.periodic(from: .now, by: 0.12)) { timeline in
                let phase = CGFloat(
                    Int(timeline.date.timeIntervalSinceReferenceDate * 8)
                )

                animatedBox(
                    phase: phase,
                    wobble: wobble * 1.8,
                    detail: 5
                )
            }

        case .flow:
            TimelineView(.animation) { timeline in
                let phase =
                    CGFloat(timeline.date.timeIntervalSinceReferenceDate) * 2.2

                animatedBox(
                    phase: phase,
                    wobble: wobble,
                    detail: 0
                )
            }

        case .none:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            strokeColor,
                            lineWidth: lineWidth
                        )
                )
        }
    }

    @ViewBuilder
    private func animatedBox(
        phase: CGFloat,
        wobble: CGFloat,
        detail: Int
    ) -> some View {

        WobblyRectangle(
            cornerRadius: cornerRadius,
            wobble: wobble,
            phase: phase,
            detail: detail
        )
        .fill(fillColor)
        .overlay(
            WobblyRectangle(
                cornerRadius: cornerRadius,
                wobble: wobble,
                phase: phase,
                detail: detail
            )
            .stroke(
                strokeColor,
                lineWidth: lineWidth
            )
        )
    }
}

// MARK: - Wobbly Rectangle

struct WobblyRectangle: Shape {

    var cornerRadius: CGFloat = 16
    var wobble: CGFloat = 4
    var phase: CGFloat = 0
    var detail: Int = 0

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {

        if detail > 0 {
            return detailedPath(in: rect)
        }

        var path = Path()

        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, min(w, h) / 2)

        func jitter(_ point: CGPoint, index: Int) -> CGPoint {
            CGPoint(
                x: point.x + deterministicOffset(index),
                y: point.y + deterministicOffset(index + 100)
            )
        }

        let topLeftStart = jitter(
            CGPoint(x: r, y: 0),
            index: 1
        )

        let topRightStart = jitter(
            CGPoint(x: w - r, y: 0),
            index: 2
        )

        let topRightEnd = jitter(
            CGPoint(x: w, y: r),
            index: 3
        )

        let bottomRightStart = jitter(
            CGPoint(x: w, y: h - r),
            index: 4
        )

        let bottomRightEnd = jitter(
            CGPoint(x: w - r, y: h),
            index: 5
        )

        let bottomLeftStart = jitter(
            CGPoint(x: r, y: h),
            index: 6
        )

        let bottomLeftEnd = jitter(
            CGPoint(x: 0, y: h - r),
            index: 7
        )

        let topLeftEnd = jitter(
            CGPoint(x: 0, y: r),
            index: 8
        )

        path.move(to: topLeftStart)

        path.addLine(to: topRightStart)

        path.addQuadCurve(
            to: topRightEnd,
            control: jitter(CGPoint(x: w, y: 0), index: 9)
        )

        path.addLine(to: bottomRightStart)

        path.addQuadCurve(
            to: bottomRightEnd,
            control: jitter(CGPoint(x: w, y: h), index: 10)
        )

        path.addLine(to: bottomLeftStart)

        path.addQuadCurve(
            to: bottomLeftEnd,
            control: jitter(CGPoint(x: 0, y: h), index: 11)
        )

        path.addLine(to: topLeftEnd)

        path.addQuadCurve(
            to: topLeftStart,
            control: jitter(CGPoint(x: 0, y: 0), index: 12)
        )

        path.closeSubpath()

        return path
    }

    private func deterministicOffset(_ index: Int) -> CGFloat {

        let base = CGFloat(index) * 1.73

        return
            sin(base + phase) * wobble * 0.75 +
            cos(base * 0.57 + phase * 1.35) * wobble * 0.25
    }

    private func detailedPath(in rect: CGRect) -> Path {

        var points: [CGPoint] = []

        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, min(w, h) / 2)
        let steps = max(2, detail)

        var index = 0

        func appendPoint(_ point: CGPoint) {

            index += 1

            points.append(
                CGPoint(
                    x: point.x + deterministicOffset(index),
                    y: point.y + deterministicOffset(index + 100)
                )
            )
        }

        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)

            appendPoint(
                CGPoint(
                    x: r + (w - 2 * r) * t,
                    y: 0
                )
            )
        }

        for step in 1...steps {

            let angle =
                -.pi / 2 +
                (CGFloat(step) / CGFloat(steps)) * (.pi / 2)

            appendPoint(
                CGPoint(
                    x: w - r + cos(angle) * r,
                    y: r + sin(angle) * r
                )
            )
        }

        for step in 1...steps {

            let t = CGFloat(step) / CGFloat(steps)

            appendPoint(
                CGPoint(
                    x: w,
                    y: r + (h - 2 * r) * t
                )
            )
        }

        for step in 1...steps {

            let angle =
                (CGFloat(step) / CGFloat(steps)) * (.pi / 2)

            appendPoint(
                CGPoint(
                    x: w - r + cos(angle) * r,
                    y: h - r + sin(angle) * r
                )
            )
        }

        for step in 1...steps {

            let t = CGFloat(step) / CGFloat(steps)

            appendPoint(
                CGPoint(
                    x: w - r - (w - 2 * r) * t,
                    y: h
                )
            )
        }

        for step in 1...steps {

            let angle =
                .pi / 2 +
                (CGFloat(step) / CGFloat(steps)) * (.pi / 2)

            appendPoint(
                CGPoint(
                    x: r + cos(angle) * r,
                    y: h - r + sin(angle) * r
                )
            )
        }

        for step in 1...steps {

            let t = CGFloat(step) / CGFloat(steps)

            appendPoint(
                CGPoint(
                    x: 0,
                    y: h - r - (h - 2 * r) * t
                )
            )
        }

        for step in 1...steps {

            let angle =
                .pi +
                (CGFloat(step) / CGFloat(steps)) * (.pi / 2)

            appendPoint(
                CGPoint(
                    x: r + cos(angle) * r,
                    y: r + sin(angle) * r
                )
            )
        }

        var path = Path()

        guard
            let first = points.first,
            let last = points.last
        else {
            return path
        }

        path.move(to: midpoint(last, first))

        for i in points.indices {

            let current = points[i]
            let next = points[(i + 1) % points.count]

            path.addQuadCurve(
                to: midpoint(current, next),
                control: current
            )
        }

        path.closeSubpath()

        return path
    }

    private func midpoint(
        _ a: CGPoint,
        _ b: CGPoint
    ) -> CGPoint {

        CGPoint(
            x: (a.x + b.x) / 2,
            y: (a.y + b.y) / 2
        )
    }
}

// MARK: - Wobbly Circle

struct WobblyCircle: Shape {

    var wobble: CGFloat = 2
    var pointCount: Int = 24
    var phase: CGFloat = 0

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {

        var path = Path()

        let center = CGPoint(
            x: rect.midX,
            y: rect.midY
        )

        let radius = min(rect.width, rect.height) / 2

        let points = (0..<pointCount).map { index in

            let angle =
                CGFloat(index) /
                CGFloat(pointCount) *
                2 * .pi

            let value =
                sin(CGFloat(index) * 12.9898 + phase)
                * 43758.5453

            let fraction = value - floor(value)

            let jitterRadius =
                radius +
                (fraction * 2 - 1) * wobble

            return CGPoint(
                x: center.x + cos(angle) * jitterRadius,
                y: center.y + sin(angle) * jitterRadius
            )
        }

        guard
            let first = points.first,
            let last = points.last
        else {
            return path
        }

        path.move(to: midpoint(last, first))

        for i in points.indices {

            let current = points[i]
            let next = points[(i + 1) % points.count]

            path.addQuadCurve(
                to: midpoint(current, next),
                control: current
            )
        }

        path.closeSubpath()

        return path
    }

    private func midpoint(
        _ a: CGPoint,
        _ b: CGPoint
    ) -> CGPoint {

        CGPoint(
            x: (a.x + b.x) / 2,
            y: (a.y + b.y) / 2
        )
    }
}