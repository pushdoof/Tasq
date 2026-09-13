import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @Binding var defaultZoom: Double
    let showsSkipButton: Bool
    let onFinish: () -> Void
    @State private var currentStep = 0

    init(hasSeenOnboarding: Binding<Bool>, defaultZoom: Binding<Double>, showsSkipButton: Bool = true,
         onFinish: @escaping () -> Void = {}) {
        self._hasSeenOnboarding = hasSeenOnboarding
        self._defaultZoom = defaultZoom
        self.showsSkipButton = showsSkipButton
        self.onFinish = onFinish
    }

    private let titles = ["A little plan goes a long way.", "One thing at a time.", "Your own little corner."]
    private let descriptions = [
        "Make a routine from scratch, or borrow a template. Each box is one small step in your day.",
        "Start a routine to focus on your next step. Pause whenever you need, or tap Done to move on early.",
        "Your routines and your people, together in Tasq. A diary and AI helper will join them later."
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                HStack {
                    Text("Tasq").doodleFont(32, relativeTo: .title).bold()
                    Spacer()
                    DoodleBadge(title: "\(currentStep + 1) OF 3")
                }
                .padding(.bottom, 12)

                illustration
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .chartflowBox(cornerRadius: 28, wobble: 1.5,
                                  fillColor: currentStep == 2 ? .tasqPeach : .tasqSage,
                                  strokeColor: .chartflowText, lineWidth: 1.7)

                Text(titles[currentStep])
                    .doodleFont(36, relativeTo: .largeTitle).bold()
                    .multilineTextAlignment(.center)
                Text(descriptions[currentStep])
                    .doodleFont(23, relativeTo: .body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.chartflowSecondaryText)

                HStack(spacing: 10) {
                    if currentStep > 0 {
                        Button { currentStep -= 1 } label: {
                            TasqIcon("chevron.left", size: 17)
                        }.buttonStyle(DoodleButtonStyle())
                            .accessibilityLabel("Previous step")
                    }
                    Button {
                        if currentStep == 2 { finish() } else { currentStep += 1 }
                    } label: {
                        Text(currentStep == 2 ? "Let's make room for my day" : "Next")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(DoodleButtonStyle(prominent: true))
                }
                if showsSkipButton && currentStep < 2 {
                    Button("I'll explore on my own") { finish() }
                        .doodleFont(18, relativeTo: .body)
                        .frame(minHeight: 44)
                }
            }
            .foregroundStyle(Color.chartflowText)
            .padding(28)
            .frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .background(PolkaDotBackground().ignoresSafeArea())
    }

    @ViewBuilder
    private var illustration: some View {
        if currentStep == 0 {
            VStack(spacing: 6) {
                sampleStep("Clear your space", icon: "checkmark.circle", detail: "5 min")
                TasqIcon("arrow.down", size: 17).frame(height: 25)
                sampleStep("A little focus", icon: "pencil", detail: "25 min")
                TasqIcon("arrow.down", size: 17).frame(height: 25)
                sampleStep("Take a breather", icon: "heart", detail: "5 min")
            }
        } else if currentStep == 1 {
            VStack(spacing: 18) {
                DoodleBadge(title: "JUST THIS ONE THING", tint: .chartflowSurface)
                Text("A little focus").doodleFont(28, relativeTo: .title2).bold()
                Text("25:00").doodleFont(62, relativeTo: .largeTitle).monospacedDigit()
                Text("Your pace. Your space.").doodleFont(20, relativeTo: .body)
            }.padding(.vertical, 15)
        } else {
            VStack(spacing: 18) {
                DoodleSun()
                sampleStep("Routines", icon: "list.bullet.rectangle", detail: "Plan")
                sampleStep("Friend Hub", icon: "person.2.fill", detail: "Connect")
                Text("Later: reflect with Diary + plan with AI")
                    .doodleFont(16, relativeTo: .caption)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func sampleStep(_ name: String, icon: String, detail: String) -> some View {
        HStack(spacing: 12) {
            TasqIcon(icon, size: 19).frame(width: 25)
            Text(name).doodleFont(21, relativeTo: .body)
            Spacer(minLength: 0)
            Text(detail).doodleFont(15, relativeTo: .caption)
        }
        .padding(15)
        .chartflowBox(cornerRadius: 14, wobble: 1, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.3)
        .accessibilityElement(children: .combine)
    }

    private func finish() {
        hasSeenOnboarding = true
        onFinish()
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false), defaultZoom: .constant(1.3))
}
