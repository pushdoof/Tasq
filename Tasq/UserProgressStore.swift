import Foundation
import FirebaseAuth
import FirebaseFirestore
internal import Combine

@MainActor
final class UserProgressStore: ObservableObject {
    @Published var charts: [Chart] = []
    @Published var hasSeenOnboarding = false
    @Published var defaultZoom = 1.3
    @Published var isLoading = false
    @Published var errorMessage: String?

    // This Firebase project uses the named Firestore database "default".
    // Firestore.firestore() targets the special "(default)" database instead.
    private let database = Firestore.firestore(database: "default")
    private var currentUserID: String?
    private var listener: ListenerRegistration?
    private var debounceTask: Task<Void, Never>?
    private var pendingState: UserProgressState?
    private var isSaveInFlight = false
    private var flushAfterCurrentSave = false
    private var hasLoadedRemoteState = false
    private var isApplyingRemoteState = false
    private var lastSavedState: UserProgressState?

    deinit {
        listener?.remove()
        debounceTask?.cancel()
    }

    func startSyncing(for user: User?) {
        let userID = user?.uid
        guard userID != currentUserID else { return }

        listener?.remove()
        debounceTask?.cancel()
        debounceTask = nil
        pendingState = nil
        flushAfterCurrentSave = false
        currentUserID = userID
        hasLoadedRemoteState = false
        errorMessage = nil

        guard let userID else {
            resetToCleanSlate()
            return
        }

        isLoading = true
        resetToCleanSlate()

        listener = progressDocument(for: userID).addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    return
                }

                // A local write immediately echoes through the listener. Applying
                // that echo while a newer edit is queued can overwrite the edit.
                guard self.pendingState == nil, !self.isSaveInFlight else {
                    self.isLoading = false
                    return
                }

                self.apply(snapshot: snapshot)
            }
        }

    }

    func scheduleSave() {
        let state = currentState
        guard hasLoadedRemoteState,
              !isApplyingRemoteState,
              state != lastSavedState,
              state != pendingState,
              let userID = currentUserID else { return }

        pendingState = state
        schedulePendingSave(for: userID, after: .seconds(1))
    }

    func flushPendingSave() {
        debounceTask?.cancel()
        debounceTask = nil

        guard pendingState != nil else { return }
        if isSaveInFlight {
            flushAfterCurrentSave = true
            return
        }

        Task { [weak self] in
            await self?.savePendingState()
        }
    }

    /// Captures the current app state and saves it at an explicit user-action
    /// boundary, such as creating, deleting, or closing an edited routine.
    func commitSave() {
        let state = currentState
        guard hasLoadedRemoteState,
              !isApplyingRemoteState,
              state != lastSavedState,
              currentUserID != nil else { return }

        pendingState = state
        flushPendingSave()
    }

    private var currentState: UserProgressState {
        UserProgressState(
            charts: charts,
            hasSeenOnboarding: hasSeenOnboarding,
            defaultZoom: defaultZoom,
            preferences: UserProgressPreferences.current
        )
    }

    private func schedulePendingSave(for userID: String, after delay: Duration) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard !Task.isCancelled, self?.currentUserID == userID else { return }
            await self?.savePendingState()
        }
    }

    private func savePendingState() async {
        guard !isSaveInFlight,
              let state = pendingState,
              let userID = currentUserID,
              state != lastSavedState else {
            if pendingState == lastSavedState {
                pendingState = nil
            }
            return
        }

        debounceTask = nil
        pendingState = nil
        isSaveInFlight = true
        let didSave = await save(state, for: userID)
        isSaveInFlight = false

        if !didSave, pendingState == nil {
            pendingState = state
        }

        guard pendingState != nil else {
            flushAfterCurrentSave = false
            return
        }

        if flushAfterCurrentSave {
            flushAfterCurrentSave = false
            await savePendingState()
        } else if didSave {
            schedulePendingSave(for: userID, after: .milliseconds(250))
        }
    }

    private func apply(snapshot: DocumentSnapshot?) {
        isApplyingRemoteState = true
        defer {
            isApplyingRemoteState = false
            isLoading = false
            hasLoadedRemoteState = true
        }

        guard let data = snapshot?.data(), snapshot?.exists == true else {
            resetToCleanSlate()
            return
        }

        if let chartsValue = data["charts"] as? String,
           let chartData = Data(base64Encoded: chartsValue),
           let decodedCharts = try? JSONDecoder().decode([Chart].self, from: chartData) {
            charts = decodedCharts
        } else {
            charts = []
        }

        hasSeenOnboarding = data["hasSeenOnboarding"] as? Bool ?? false
        defaultZoom = data["defaultZoom"] as? Double ?? 1.3

        if let preferencesValue = data["preferences"] as? String,
           let preferencesData = Data(base64Encoded: preferencesValue),
           let preferences = try? JSONDecoder().decode(UserProgressPreferences.self, from: preferencesData) {
            applyPreferences(preferences)
        } else {
            applyPreferences(.defaults)
        }

        lastSavedState = UserProgressState(
            charts: charts,
            hasSeenOnboarding: hasSeenOnboarding,
            defaultZoom: defaultZoom,
            preferences: UserProgressPreferences.current
        )
    }

    private func save(_ state: UserProgressState, for userID: String) async -> Bool {
        do {
            let encodedCharts = try JSONEncoder().encode(state.charts).base64EncodedString()
            let encodedPreferences = try JSONEncoder().encode(state.preferences).base64EncodedString()
            try await progressDocument(for: userID).setData([
                "charts": encodedCharts,
                "hasSeenOnboarding": state.hasSeenOnboarding,
                "defaultZoom": state.defaultZoom,
                "preferences": encodedPreferences,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            lastSavedState = state
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func progressDocument(for userID: String) -> DocumentReference {
        database
            .collection("users")
            .document(userID)
            .collection("progress")
            .document("appState")
    }

    private func resetToCleanSlate() {
        charts = []
        hasSeenOnboarding = false
        defaultZoom = 1.3
        applyPreferences(.defaults)
        lastSavedState = UserProgressState(
            charts: charts,
            hasSeenOnboarding: hasSeenOnboarding,
            defaultZoom: defaultZoom,
            preferences: UserProgressPreferences.current
        )
    }

    private func applyPreferences(_ preferences: UserProgressPreferences) {
        isApplyingRemoteState = true
        preferences.save()
        isApplyingRemoteState = false
    }
}

private struct UserProgressState: Equatable {
    var charts: [Chart]
    var hasSeenOnboarding: Bool
    var defaultZoom: Double
    var preferences: UserProgressPreferences
}

private struct UserProgressPreferences: Codable, Equatable {
    var darkModeEnabled: Bool
    var boxMovementEffect: String
    var backgroundPattern: String
    var reduceBoxMotion: Bool
    var highContrastBoxes: Bool
    var largerText: Bool
    var boldText: Bool
    var calmCelebrations: Bool
    var friendAvatarX: Double
    var friendAvatarY: Double
    var friendAvatarBodyColor: String
    var friendAvatarMouth: String
    var friendAvatarEyes: String
    var friendAvatarHair: String
    var friendAvatarFur: String
    var friendAvatarItem: String
    var friendAvatarHairHue: Double
    var friendAvatarHairSaturation: Double
    var friendAvatarHairBrightness: Double
    var friendAvatarScarfHue: Double

    static let defaults = UserProgressPreferences(
        darkModeEnabled: false,
        boxMovementEffect: BoxMovementEffect.doodle.rawValue,
        backgroundPattern: TasqBackgroundPattern.dots.rawValue,
        reduceBoxMotion: false,
        highContrastBoxes: false,
        largerText: false,
        boldText: false,
        calmCelebrations: false,
        friendAvatarX: 0.5,
        friendAvatarY: 0.58,
        friendAvatarBodyColor: FriendAvatarBodyColor.skin7.rawValue,
        friendAvatarMouth: FriendAvatarMouth.none.rawValue,
        friendAvatarEyes: FriendAvatarEyes.none.rawValue,
        friendAvatarHair: FriendAvatarHair.none.rawValue,
        friendAvatarFur: FriendAvatarFur.none.rawValue,
        friendAvatarItem: FriendAvatarItem.none.rawValue,
        friendAvatarHairHue: 0.0,
        friendAvatarHairSaturation: 0.72,
        friendAvatarHairBrightness: 0.86,
        friendAvatarScarfHue: 0.78
    )

    static var current: UserProgressPreferences {
        let defaults = UserDefaults.standard
        return UserProgressPreferences(
            darkModeEnabled: defaults.bool(forKey: "darkModeEnabled"),
            boxMovementEffect: defaults.string(forKey: "boxMovementEffect") ?? Self.defaults.boxMovementEffect,
            backgroundPattern: defaults.string(forKey: "backgroundPattern") ?? Self.defaults.backgroundPattern,
            reduceBoxMotion: defaults.bool(forKey: "reduceBoxMotion"),
            highContrastBoxes: defaults.bool(forKey: "highContrastBoxes"),
            largerText: defaults.bool(forKey: "largerText"),
            boldText: defaults.bool(forKey: "boldText"),
            calmCelebrations: defaults.bool(forKey: "calmCelebrations"),
            friendAvatarX: defaults.object(forKey: "friendAvatarX") as? Double ?? Self.defaults.friendAvatarX,
            friendAvatarY: defaults.object(forKey: "friendAvatarY") as? Double ?? Self.defaults.friendAvatarY,
            friendAvatarBodyColor: defaults.string(forKey: "friendAvatarBodyColor") ?? Self.defaults.friendAvatarBodyColor,
            friendAvatarMouth: defaults.string(forKey: "friendAvatarMouth") ?? Self.defaults.friendAvatarMouth,
            friendAvatarEyes: defaults.string(forKey: "friendAvatarEyes") ?? Self.defaults.friendAvatarEyes,
            friendAvatarHair: defaults.string(forKey: "friendAvatarHair") ?? Self.defaults.friendAvatarHair,
            friendAvatarFur: defaults.string(forKey: "friendAvatarFur") ?? Self.defaults.friendAvatarFur,
            friendAvatarItem: defaults.string(forKey: "friendAvatarItem") ?? Self.defaults.friendAvatarItem,
            friendAvatarHairHue: defaults.object(forKey: "friendAvatarHairHue") as? Double ?? Self.defaults.friendAvatarHairHue,
            friendAvatarHairSaturation: defaults.object(forKey: "friendAvatarHairSaturation") as? Double ?? Self.defaults.friendAvatarHairSaturation,
            friendAvatarHairBrightness: defaults.object(forKey: "friendAvatarHairBrightness") as? Double ?? Self.defaults.friendAvatarHairBrightness,
            friendAvatarScarfHue: defaults.object(forKey: "friendAvatarScarfHue") as? Double ?? Self.defaults.friendAvatarScarfHue
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(darkModeEnabled, forKey: "darkModeEnabled")
        defaults.set(boxMovementEffect, forKey: "boxMovementEffect")
        defaults.set(backgroundPattern, forKey: "backgroundPattern")
        defaults.set(reduceBoxMotion, forKey: "reduceBoxMotion")
        defaults.set(highContrastBoxes, forKey: "highContrastBoxes")
        defaults.set(largerText, forKey: "largerText")
        defaults.set(boldText, forKey: "boldText")
        defaults.set(calmCelebrations, forKey: "calmCelebrations")
        defaults.set(friendAvatarX, forKey: "friendAvatarX")
        defaults.set(friendAvatarY, forKey: "friendAvatarY")
        defaults.set(friendAvatarBodyColor, forKey: "friendAvatarBodyColor")
        defaults.set(friendAvatarMouth, forKey: "friendAvatarMouth")
        defaults.set(friendAvatarEyes, forKey: "friendAvatarEyes")
        defaults.set(friendAvatarHair, forKey: "friendAvatarHair")
        defaults.set(friendAvatarFur, forKey: "friendAvatarFur")
        defaults.set(friendAvatarItem, forKey: "friendAvatarItem")
        defaults.set(friendAvatarHairHue, forKey: "friendAvatarHairHue")
        defaults.set(friendAvatarHairSaturation, forKey: "friendAvatarHairSaturation")
        defaults.set(friendAvatarHairBrightness, forKey: "friendAvatarHairBrightness")
        defaults.set(friendAvatarScarfHue, forKey: "friendAvatarScarfHue")
    }
}
