import SwiftUI
import FirebaseCore
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
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
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    TasqSplashView()
                } else if authStore.isSignedIn {
                    Group {
                        if progressStore.isLoading {
                            ProgressView()
                                .tint(Color.chartflowText)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.chartflowBackground)
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
            .preferredColorScheme(darkModeEnabled ? .dark : .light)
            .onChange(of: authStore.user) { _, user in
                progressStore.startSyncing(for: user)
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
