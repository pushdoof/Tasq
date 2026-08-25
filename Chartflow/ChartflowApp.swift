import SwiftUI
import FirebaseCore

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
struct ChartflowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var charts: [Chart] = Self.loadCharts()
    @State private var showSplash = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("defaultZoom") private var defaultZoom: Double = 1.3
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    ChartflowSplashView()
                } else {
                    Group {
                        if hasSeenOnboarding {
                            MindflowHomeScreen(charts: $charts)
                                .onChange(of: charts) { _, newCharts in
                                    Self.saveCharts(newCharts)
                                }
                        } else {
                            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding, defaultZoom: $defaultZoom)
                        }
                    }
                }
            }
            .preferredColorScheme(darkModeEnabled ? .dark : .light)
            .task {
                guard showSplash else { return }
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.easeOut(duration: 0.25)) {
                    showSplash = false
                }
            }
        }
    }

    static func saveCharts(_ charts: [Chart]) {
        if let encoded = try? JSONEncoder().encode(charts) {
            UserDefaults.standard.set(encoded, forKey: "savedCharts")
        }
    }

    static func loadCharts() -> [Chart] {
        if let data = UserDefaults.standard.data(forKey: "savedCharts"),
           let decoded = try? JSONDecoder().decode([Chart].self, from: data) {
            return decoded
        }
        return [Chart.sample]
    }
}

struct ChartflowSplashView: View {
    var body: some View {
        ZStack {
            Color.chartflowBackground
                .ignoresSafeArea()

            Text("Chartflow")
                .font(.custom("ChartflowHand-Regular", size: 48))
                .fontWeight(.bold)
                .foregroundStyle(Color.chartflowText)
        }
    }
}
