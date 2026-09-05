//
//  OnboardingView.swift
//  Chartflow
//

import SwiftUI
internal import Combine

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @Binding var defaultZoom: Double
    let showsSkipButton: Bool
    let onFinish: () -> Void
    @State private var currentStep = 0
    @State private var refreshTrigger = false
    @State private var selectedZoom: Double = 1.3

    init(
        hasSeenOnboarding: Binding<Bool>,
        defaultZoom: Binding<Double>,
        showsSkipButton: Bool = true,
        onFinish: @escaping () -> Void = {}
    ) {
        self._hasSeenOnboarding = hasSeenOnboarding
        self._defaultZoom = defaultZoom
        self.showsSkipButton = showsSkipButton
        self.onFinish = onFinish
    }

    let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Welcome to Chartflow",
            subtitle: "Your daily routines, visualized as a flowchart.",
            icon: "hand.wave.fill",
            description: "Chartflow helps you build, time, and follow through on your daily routines; one task at a time."
        ),
        OnboardingStep(
            title: "Your Routines",
            subtitle: "All your routines, in one place.",
            icon: "list.bullet.rectangle",
            description: "The home screen shows all your routines as cards. Tap one to open it, press + to add a new one, or use the trash icon to delete."
        ),
        OnboardingStep(
            title: "The Chart Editor",
            subtitle: "Build your routine as a flowchart.",
            icon: "arrow.right.square",
            description: "Each box is a task. Tap + to add tasks, tap the time to set its duration, and tap the pencil to rename tasks. Tap a box to mark it complete."
        ),
        OnboardingStep(
            title: "The Timer",
            subtitle: "Follow your routine, step by step.",
            icon: "play.circle.fill",
            description: "Press the play button to start your routine. Each task counts down automatically and advances to the next when time is up — or tap the box to move on early."
        ),
        OnboardingStep(
            title: "The Alarm Block",
            subtitle: "Start your routine at a set time.",
            icon: "alarm.fill",
            description: "Turn on the alarm block from the side menu to pick a start time. When it is on, each task shows what time it should finish."
        ),
        OnboardingStep(
            title: "Set Your Zoom",
            subtitle: "Pick a default chart size.",
            icon: "magnifyingglass",
            description: "Choose how zoomed in the flowchart is by default. You can always change it later using the zoom buttons in the editor."
        )
    ]

    let zoomOptions: [(String, Double)] = [
        ("80%", 0.8),
        ("100%", 1.0),
        ("130%", 1.3),
        ("160%", 1.6),
        ("200%", 2.0)
    ]

    var isLastStep: Bool { currentStep == steps.count - 1 }

    var body: some View {
        ZStack {
            PolkaDotBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.chartflowSurface)
                        .frame(width: 110, height: 110)
                        .overlay(
                            WobblyCircle(wobble: 2)
                                .stroke(Color.chartflowText, lineWidth: 2.5)
                                .id(refreshTrigger)
                        )
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 46))
                        .foregroundStyle(Color.chartflowText)
                }
                .padding(.bottom, 36)

                Text(steps[currentStep].title)
                    .font(.custom("ChartflowHand-Regular", size: 36))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.chartflowText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text(steps[currentStep].subtitle)
                    .font(.custom("ChartflowHand-Regular", size: 22))
                    .foregroundStyle(Color.chartflowText.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 10)

                Text(steps[currentStep].description)
                    .font(.custom("ChartflowHand-Regular", size: 26))
                    .foregroundStyle(Color.chartflowText)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .background(
                        WobblyRectangle(cornerRadius: 16, wobble: 2)
                            .fill(Color.chartflowSurface)
                            .id(refreshTrigger)
                    )
                    .overlay(
                        WobblyRectangle(cornerRadius: 16, wobble: 2)
                            .stroke(Color.chartflowText, lineWidth: 2)
                            .id(refreshTrigger)
                    )
                    .padding(.horizontal, 28)
                    .padding(.top, 24)

                if isLastStep {
                    VStack(spacing: 12) {
                        Text("Choose your default zoom:")
                            .font(.custom("ChartflowHand-Regular", size: 20))
                            .foregroundStyle(Color.chartflowText)
                            .padding(.top, 24)

                        HStack(spacing: 10) {
                            ForEach(zoomOptions, id: \.1) { label, value in
                                Button {
                                    selectedZoom = value
                                } label: {
                                    Text(label)
                                        .font(.custom("ChartflowHand-Regular", size: 17))
                                        .foregroundStyle(selectedZoom == value ? Color.chartflowBackground : Color.chartflowText)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .background(selectedZoom == value ? Color.chartflowText : Color.chartflowSurface)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.chartflowText, lineWidth: 1.5)
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentStep ? Color.chartflowText : Color.chartflowSecondaryText.opacity(0.35))
                            .frame(width: 10, height: 10)
                            .animation(.easeInOut, value: currentStep)
                    }
                }
                .padding(.bottom, 24)

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if isLastStep {
                            finishOnboarding()
                        } else {
                            currentStep += 1
                        }
                    }
                } label: {
                    Text(isLastStep ? "Get Started" : "Next")
                        .font(.custom("ChartflowHand-Regular", size: 22))
                        .foregroundStyle(Color.chartflowBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.chartflowText)
                        .cornerRadius(16)
                        .padding(.horizontal, 28)
                }

                if showsSkipButton && !isLastStep {
                    Button {
                        withAnimation {
                            finishOnboarding()
                        }
                    } label: {
                        Text("Skip")
                            .font(.custom("ChartflowHand-Regular", size: 18))
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 14)
                }

                Spacer().frame(height: 44)
            }
        }
        .onReceive(Timer.publish(every: 0.10, on: .main, in: .common).autoconnect()) { _ in
            refreshTrigger.toggle()
        }
        .onAppear {
            selectedZoom = defaultZoom
        }
    }

    private func finishOnboarding() {
        defaultZoom = selectedZoom
        hasSeenOnboarding = true
        onFinish()
    }
}

struct OnboardingStep {
    let title: String
    let subtitle: String
    let icon: String
    let description: String
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false), defaultZoom: .constant(1.3))
}
