import SwiftUI
import FirebaseCore
import UserNotifications
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = TasqNotificationRouter.shared
        // Remove pre-migration reminders that could point to the wrong routine.
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let legacy = requests.map(\.identifier).filter {
                $0 == "alarm"
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: legacy)
        }
        return true
    }

}

@main
struct TasqApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var authStore = AuthenticationStore()
    @StateObject private var progressStore = UserProgressStore()
    @State private var showSplash = true
    @State private var forceAccountSetupWizard = false
    @AppStorage("appearanceMode") private var appearanceModeRaw = TasqAppearanceMode.system.rawValue
    @AppStorage("interfaceScale") private var interfaceScale = 1.0

    private var isFriendHubVisualCheck: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-friend-hub-preview")
        #else
        false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isFriendHubVisualCheck {
                    #if DEBUG
                    FriendGroupVisualCheck()
                    #endif
                } else if showSplash {
                    TasqSplashView()
                } else if authStore.isSignedIn {
                    Group {
                        if progressStore.isLoading {
                            ProgressView()
                                .tint(Color.chartflowText)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.chartflowBackground)
                        } else if progressStore.needsAccountSetup || forceAccountSetupWizard {
                            AccountSetupWizardView(
                                birthday: $progressStore.birthday,
                                appearanceMode: appearanceMode,
                                interfaceScale: $interfaceScale,
                                finishSetup: {
                                    forceAccountSetupWizard = false
                                    progressStore.completeAccountSetup(
                                        birthday: progressStore.birthday,
                                        defaultZoom: progressStore.defaultZoom,
                                        appearanceMode: TasqAppearanceMode(rawValue: appearanceModeRaw) ?? .system
                                    )
                                }
                            )
                        } else if progressStore.hasSeenOnboarding {
                            MindflowHomeScreen(charts: $progressStore.charts, defaultZoom: $progressStore.defaultZoom)
                        } else {
                            OnboardingView(hasSeenOnboarding: $progressStore.hasSeenOnboarding, defaultZoom: $progressStore.defaultZoom)
                        }
                    }
                } else {
                    AuthenticationView()
                }
            }
            .environmentObject(authStore)
            .environmentObject(progressStore)
            .environment(\.interfaceScale, interfaceScale)
            .preferredColorScheme((TasqAppearanceMode(rawValue: appearanceModeRaw) ?? .system).colorScheme)
            .background {
                SecretKeySequenceReader(sequence: "pushyaduttcoolmonkeyrafi") {
                    guard authStore.isSignedIn, !showSplash else { return }
                    forceAccountSetupWizard = true
                }
            }
            .onChange(of: authStore.user) { _, user in
                progressStore.startSyncing(for: user)
                forceAccountSetupWizard = false
            }
            .onChange(of: progressStore.charts) { _, _ in
                progressStore.scheduleSave()
            }
            .onChange(of: progressStore.hasSeenOnboarding) { _, _ in
                progressStore.scheduleSave()
            }
            .onChange(of: progressStore.defaultZoom) { _, _ in
                progressStore.scheduleSave()
            }
            .onChange(of: interfaceScale) { _, _ in
                progressStore.scheduleSave()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    progressStore.commitSave()
                }
            }
            .onOpenURL { url in
                #if canImport(GoogleSignIn)
                GIDSignIn.sharedInstance.handle(url)
                #endif
            }
            .task {
                guard showSplash else { return }
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.easeOut(duration: 0.25)) {
                    showSplash = false
                }
            }
            .onAppear {
                progressStore.startSyncing(for: authStore.user)
            }
        }
    }

    private var appearanceMode: Binding<TasqAppearanceMode> {
        Binding {
            TasqAppearanceMode(rawValue: appearanceModeRaw) ?? .system
        } set: { newValue in
            newValue.save()
            appearanceModeRaw = newValue.rawValue
            progressStore.scheduleSave()
        }
    }
}

private struct SecretKeySequenceReader: UIViewRepresentable {
    let sequence: String
    let onMatch: () -> Void

    func makeUIView(context: Context) -> SecretKeySequenceView {
        let view = SecretKeySequenceView()
        view.sequence = sequence
        view.onMatch = onMatch
        DispatchQueue.main.async {
            view.becomeFirstResponder()
        }
        return view
    }

    func updateUIView(_ uiView: SecretKeySequenceView, context: Context) {
        uiView.sequence = sequence
        uiView.onMatch = onMatch
        DispatchQueue.main.async {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
    }
}

private final class SecretKeySequenceView: UIView {
    var sequence = ""
    var onMatch: (() -> Void)?
    private var buffer = ""

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handledPress = false

        for press in presses {
            guard let key = press.key,
                  key.modifierFlags.isEmpty,
                  let character = key.charactersIgnoringModifiers.lowercased().first else {
                continue
            }

            buffer.append(character)
            if buffer.count > sequence.count {
                buffer = String(buffer.suffix(sequence.count))
            }

            if buffer == sequence {
                buffer = ""
                onMatch?()
            }

            handledPress = true
        }

        if !handledPress {
            super.pressesBegan(presses, with: event)
        }
    }
}

struct TasqSplashView: View {
    var body: some View {
        ZStack {
            Color.chartflowBackground
                .ignoresSafeArea()

            Text("Tasq")
                .font(.custom("ChartflowHand-Regular", size: 48))
                .fontWeight(.bold)
                .foregroundStyle(Color.chartflowText)
        }
    }
}
