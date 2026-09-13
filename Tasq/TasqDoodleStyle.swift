import SwiftUI

extension Color {
    static let tasqSage = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.20, green: 0.29, blue: 0.23, alpha: 1)
        : UIColor(red: 0.87, green: 0.93, blue: 0.81, alpha: 1) })
    static let tasqPeach = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.34, green: 0.23, blue: 0.20, alpha: 1)
        : UIColor(red: 1, green: 0.88, blue: 0.79, alpha: 1) })
    static let tasqLilac = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.26, green: 0.23, blue: 0.34, alpha: 1)
        : UIColor(red: 0.91, green: 0.88, blue: 0.97, alpha: 1) })
}

struct DoodleButtonStyle: ButtonStyle {
    var prominent = false
    var tint: Color = .chartflowSurface
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .doodleFont(20, relativeTo: .headline)
            .fontWeight(.bold)
            .foregroundStyle(prominent ? Color.chartflowBackground : Color.chartflowText)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(minHeight: 48)
            .chartflowBox(cornerRadius: 17, wobble: 1.4,
                          fillColor: prominent ? .chartflowText : tint,
                          strokeColor: .chartflowText, lineWidth: 1.6)
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.4)
    }
}

struct DoodleBadge: View {
    let title: String
    var tint: Color = .tasqSage

    var body: some View {
        Text(title)
            .doodleFont(14, relativeTo: .caption)
            .fontWeight(.bold)
            .foregroundStyle(Color.chartflowText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .chartflowBox(cornerRadius: 8, wobble: 0.8, fillColor: tint,
                          strokeColor: .chartflowText.opacity(0.4), lineWidth: 1)
    }
}

struct DoodleSectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .doodleFont(28, relativeTo: .title2)
                .fontWeight(.bold)
            Text(subtitle)
                .doodleFont(17, relativeTo: .subheadline)
                .foregroundStyle(Color.chartflowSecondaryText)
        }
        .foregroundStyle(Color.chartflowText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A quiet, code-drawn doodle that also works in dark mode and Reduce Motion.
struct DoodleSun: View {
    var body: some View {
        ZStack {
            ForEach(0..<10) { ray in
                Capsule().fill(Color.chartflowText)
                    .frame(width: 2, height: 9)
                    .offset(y: -30)
                    .rotationEffect(.degrees(Double(ray) * 36))
            }
            WobblyCircle(wobble: 1).fill(Color.tasqPeach)
                .frame(width: 40, height: 40)
            WobblyCircle(wobble: 1).stroke(Color.chartflowText, lineWidth: 1.5)
                .frame(width: 40, height: 40)
            Text("◡").font(.system(size: 22)).offset(y: 2)
                .foregroundStyle(Color.chartflowText)
        }
        .frame(width: 72, height: 72)
        .rotationEffect(.degrees(10))
        .accessibilityHidden(true)
    }
}

private struct DoodleFont: ViewModifier {
    let size: CGFloat
    let style: Font.TextStyle
    @Environment(\.interfaceScale) private var interfaceScale

    func body(content: Content) -> some View {
        content.font(.custom("ChartflowHand-Regular", size: size * interfaceScale, relativeTo: style))
    }
}

extension View {
    func doodleFont(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(DoodleFont(size: size, style: style))
    }
}
