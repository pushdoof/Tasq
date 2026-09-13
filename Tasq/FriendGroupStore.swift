import Foundation
import FirebaseFirestore
internal import Combine

struct FriendRoomPresence: Identifiable, Codable {
    var id: String
    var userID: String
    var name: String
    var avatar: FriendAvatarConfig
    var roomID: String
    var x: Double
    var y: Double
    var isMoving: Bool
    var lastSeen: Date
    var reaction: String = ""
    // Firestore rejects Date.distantPast (before its year-1 lower bound).
    // An empty reaction uses the Unix epoch, which is supported and long expired.
    var reactionAt: Date = Date(timeIntervalSince1970: 0)
}

@MainActor
final class FriendGroupStore: ObservableObject {
    @Published private(set) var groups: [FriendGroup] = []
    @Published private(set) var presence: [FriendRoomPresence] = []
    @Published private(set) var messages: [FriendGroupMessage] = []
    @Published private(set) var game = FriendGroupGame()
    @Published private(set) var focusEndsAt: Date?
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published var errorMessage = ""
    @Published private(set) var connection = "Connecting…"
    @Published var selectedGroupID: String?
    @Published private(set) var room: FriendGroupRoom = .lounge
    @Published private(set) var localPresence: FriendRoomPresence?

    #if DEBUG
    private var visualCheck = false
    func prepareVisualCheck(account: FriendHubAccount, empty: Bool = false) {
        visualCheck = true
        self.account = account
        groups = ["The cozy crew", "Study buddies", "Weekend people", "Just us"].enumerated().map { index, name in
            FriendGroup(id: "preview-\(index)", name: name, adminID: account.id,
                memberIDs: [account.id, "milo", "jules"], memberNames: [account.id: "You", "milo": "Milo", "jules": "Jules"], createdAt: .now)
        }
        if empty { groups = [] }
        isLoading = false
    }
    #endif

    private lazy var db = Firestore.firestore(database: "default")
    private var groupsListener: ListenerRegistration?
    private var roomListeners: [ListenerRegistration] = []
    private var account: FriendHubAccount?
    private var sessionID: String?
    private var activeGroupID: String?
    private var movementTask: Task<Void, Never>?
    private var lastPositionWrite = Date.distantPast
    private var generation = UUID()

    var selectedGroup: FriendGroup? { groups.first { $0.id == selectedGroupID } }
    var isAdmin: Bool { selectedGroup?.adminID == account?.id }
    var userID: String { account?.id ?? "" }

    deinit {
        groupsListener?.remove()
        roomListeners.forEach { $0.remove() }
        movementTask?.cancel()
    }

    func start(account: FriendHubAccount) {
        stop()
        self.account = account
        isLoading = true
        let token = generation
        groupsListener = db.collection("friendHubGroups")
            .whereField("memberIDs", arrayContains: account.id)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    self.isLoading = false
                    if let error { self.fail(error); return }
                    self.groups = (snapshot?.documents.compactMap { try? $0.data(as: FriendGroup.self) } ?? [])
                        .sorted { $0.createdAt < $1.createdAt }
                    if let id = self.selectedGroupID, !self.groups.contains(where: { $0.id == id }) {
                        self.selectedGroupID = nil
                        self.endRoom()
                    }
                    if let group = self.selectedGroup, !group.rooms.contains(self.room) {
                        self.changeRoom(.lounge)
                    }
                }
            }
    }

    func stop() {
        generation = UUID()
        groupsListener?.remove(); groupsListener = nil
        endRoom()
        account = nil; groups = []; selectedGroupID = nil
    }

    func create(name: String, friends: [FriendHubAccount], games: Bool, focus: Bool) async -> Bool {
        guard let account, !isSaving else { return false }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 32, friends.count < 20 else {
            errorMessage = "Give your group a name (up to 32 characters) and choose up to 19 friends."
            return false
        }
        let ref = db.collection("friendHubGroups").document()
        var names = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0.displayName) })
        names[account.id] = account.displayName
        let group = FriendGroup(id: ref.documentID, name: name, adminID: account.id,
                                memberIDs: Array(Set(friends.map(\.id) + [account.id])).sorted(),
                                memberNames: names, gamesEnabled: games, focusEnabled: focus, createdAt: .now)
        return await save {
            var data = try Firestore.Encoder().encode(group)
            data["createdAt"] = FieldValue.serverTimestamp()
            try await ref.setData(data)
        }
    }

    func update(group: FriendGroup, name: String, members: [String], names: [String: String],
                adminID: String, games: Bool, focus: Bool) async -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard group.adminID == userID, !name.isEmpty, name.count <= 32,
              members.contains(adminID), !members.isEmpty, members.count <= 20 else {
            errorMessage = "Keep an admin in the group and use a name of up to 32 characters."
            return false
        }
        return await save {
            let ref = self.groupRef(group.id)
            try await self.transaction { transaction in
                let current = try transaction.getDocument(ref).data(as: FriendGroup.self)
                guard current == group else { throw FriendGroupError.settingsChanged }
                transaction.updateData([
                    "name": name, "memberIDs": members, "memberNames": names,
                    "adminID": adminID, "gamesEnabled": games, "focusEnabled": focus
                ], forDocument: ref)
            }
        }
    }

    func leaveGroup(_ group: FriendGroup) async -> Bool {
        guard group.adminID != userID else {
            errorMessage = "Transfer the admin role to another member before leaving."
            return false
        }
        return await save {
            // A transaction preserves simultaneous admin edits and membership changes.
            let ref = self.groupRef(group.id)
            let uid = self.userID
            try await self.transaction { transaction in
                let current = try transaction.getDocument(ref).data(as: FriendGroup.self)
                guard current.adminID != uid else { throw FriendGroupError.invalidAction }
                var names = current.memberNames; names.removeValue(forKey: uid)
                transaction.updateData(["memberIDs": current.memberIDs.filter { $0 != uid },
                                        "memberNames": names], forDocument: ref)
            }
        }
    }

    /// Runs for the screen's task lifetime; cancellation tears down every room subscription.
    func runRoom(groupID: String, avatar: FriendAvatarConfig) async {
        guard let account, groups.contains(where: { $0.id == groupID && $0.contains(account.id) }) else { return }
        #if DEBUG
        if visualCheck {
            localPresence = FriendRoomPresence(id: "preview-local", userID: account.id, name: "You", avatar: avatar,
                roomID: "lounge", x: 0.45, y: 0.65, isMoving: false, lastSeen: .now)
            var friend = localPresence!; friend.id = "preview-milo"; friend.userID = "milo"; friend.name = "Milo"; friend.x = 0.73; friend.y = 0.55
            friend.avatar.bodyColorRaw = "skin3"
            presence = [friend]; connection = "Preview"
            return
        }
        #endif
        endRoom()
        let session = UUID().uuidString
        sessionID = session; activeGroupID = groupID; room = .lounge
        localPresence = FriendRoomPresence(id: session, userID: account.id, name: account.displayName,
            avatar: avatar, roomID: room.rawValue, x: 0.5, y: 0.65, isMoving: false,
            lastSeen: .now)
        connection = "Connecting…"
        let ref = groupRef(groupID)
        roomListeners.append(ref.collection("presence")
            .whereField("lastSeen", isGreaterThan: Timestamp(date: Date.now.addingTimeInterval(-60)))
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.sessionID == session else { return }
                if let error { self.connection = "Connection unavailable"; self.fail(error); return }
                self.connection = snapshot?.metadata.isFromCache == true ? "Reconnecting…" : "Connected"
                self.presence = snapshot?.documents.compactMap { try? $0.data(as: FriendRoomPresence.self) } ?? []
            }
        })
        roomListeners.append(ref.collection("messages").order(by: "createdAt", descending: true).limit(to: 80)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.sessionID == session else { return }
                    if let error { self.fail(error); return }
                    self.messages = (snapshot?.documents.compactMap { try? $0.data(as: FriendGroupMessage.self) } ?? []).reversed()
                }
            })
        roomListeners.append(ref.collection("activities").document("tictactoe").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.sessionID == session else { return }
                if let error { self.fail(error); return }
                self.game = (try? snapshot?.data(as: FriendGroupGame.self)) ?? FriendGroupGame()
            }
        })
        roomListeners.append(ref.collection("activities").document("focus").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.sessionID == session else { return }
                if let error { self.fail(error); return }
                self.focusEndsAt = (snapshot?.data()?["endsAt"] as? Timestamp)?.dateValue()
            }
        })
        publishPresence()
        defer { if sessionID == session { endRoom() } }
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(20)) } catch { break }
            guard sessionID == session else { break }
            publishPresence()
        }
    }

    func endRoom() {
        movementTask?.cancel(); movementTask = nil
        roomListeners.forEach { $0.remove() }; roomListeners = []
        if let id = activeGroupID, let session = sessionID {
            // A unique document per visit prevents an old cleanup deleting a new session.
            groupRef(id).collection("presence").document(session).delete { _ in }
        }
        sessionID = nil; activeGroupID = nil; localPresence = nil
        presence = []; messages = []; game = FriendGroupGame(); focusEndsAt = nil
    }

    func changeRoom(_ next: FriendGroupRoom) {
        guard selectedGroup?.rooms.contains(next) == true else { return }
        movementTask?.cancel()
        room = next
        localPresence?.roomID = next.rawValue
        localPresence?.x = 0.5; localPresence?.y = 0.65; localPresence?.isMoving = false
        publishPresence()
    }

    func move(toX x: Double, y: Double, reducedMotion: Bool) {
        guard let local = localPresence else { return }
        movementTask?.cancel()
        let targetX = min(0.88, max(0.12, x)), targetY = min(0.87, max(0.40, y))
        let distance = hypot(targetX - local.x, targetY - local.y)
        let steps = max(1, Int(distance / 0.025))
        movementTask = Task { [weak self] in
            for step in 1...steps {
                guard let self, !Task.isCancelled, self.localPresence?.id == local.id else { return }
                let fraction = Double(step) / Double(steps)
                self.localPresence?.x = local.x + (targetX - local.x) * fraction
                self.localPresence?.y = local.y + (targetY - local.y) * fraction
                self.localPresence?.isMoving = step < steps && !reducedMotion
                if Date.now.timeIntervalSince(self.lastPositionWrite) > 0.35 || step == steps { self.publishPresence() }
                do { try await Task.sleep(for: .milliseconds(65)) } catch { return }
            }
        }
    }

    func updateAvatar(_ avatar: FriendAvatarConfig) { localPresence?.avatar = avatar; publishPresence() }
    func react(_ reaction: String) {
        guard ["👋", "✨", "❤️", "☕"].contains(reaction) else { return }
        localPresence?.reaction = reaction; localPresence?.reactionAt = .now; publishPresence()
    }

    func visiblePlayers(at date: Date) -> [FriendRoomPresence] {
        var latest: [String: FriendRoomPresence] = [:]
        for player in presence where date.timeIntervalSince(player.lastSeen) < 60 && selectedGroup?.contains(player.userID) == true {
            if latest[player.userID].map({ $0.lastSeen > player.lastSeen }) != true { latest[player.userID] = player }
        }
        if let localPresence { latest[userID] = localPresence }
        return latest.values.filter { $0.roomID == room.rawValue }.sorted { $0.y < $1.y }
    }

    func send(_ text: String) async -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validation = FriendHubChatSafety.validationMessage(for: text) { errorMessage = validation; return false }
        guard let id = activeGroupID, let account else { return false }
        let ref = groupRef(id).collection("messages").document()
        return await save {
            try await ref.setData(["id": ref.documentID, "senderID": account.id,
                "senderName": account.displayName, "text": text, "createdAt": FieldValue.serverTimestamp()])
        }
    }

    func joinGame() async {
        guard let id = activeGroupID, selectedGroup?.gamesEnabled == true else { return }
        let uid = userID, ref = groupRef(id).collection("activities").document("tictactoe")
        _ = await save {
            try await self.transaction { transaction in
                let snapshot = try transaction.getDocument(ref)
                var game = snapshot.exists ? try snapshot.data(as: FriendGroupGame.self) : FriendGroupGame()
                guard game.xID != uid, game.oID != uid else { return }
                if game.xID.isEmpty { game.xID = uid }
                else if game.oID.isEmpty { game.oID = uid }
                else { throw FriendGroupError.gameFull }
                transaction.setData(try Firestore.Encoder().encode(game), forDocument: ref)
            }
        }
    }

    func play(_ index: Int) async {
        guard let id = activeGroupID, selectedGroup?.gamesEnabled == true else { return }
        let uid = userID, ref = groupRef(id).collection("activities").document("tictactoe")
        _ = await save {
            try await self.transaction { transaction in
                var game = try transaction.getDocument(ref).data(as: FriendGroupGame.self)
                guard game.play(at: index, userID: uid) else { throw FriendGroupError.invalidAction }
                transaction.setData(try Firestore.Encoder().encode(game), forDocument: ref)
            }
        }
    }

    func resetGame() async {
        guard let group = selectedGroup, group.gamesEnabled else { return }
        let uid = userID, ref = groupRef(group.id).collection("activities").document("tictactoe")
        _ = await save {
            try await self.transaction { transaction in
                let game = try transaction.getDocument(ref).data(as: FriendGroupGame.self)
                guard group.adminID == uid || (game.winner != nil && [game.xID, game.oID].contains(uid)) else {
                    throw FriendGroupError.invalidAction
                }
                transaction.setData(try Firestore.Encoder().encode(FriendGroupGame()), forDocument: ref)
            }
        }
    }

    func setFocus(minutes: Int?) async {
        guard let group = selectedGroup, group.adminID == userID, group.focusEnabled else { return }
        _ = await save {
            let ref = self.groupRef(group.id).collection("activities").document("focus")
            if let minutes { try await ref.setData(["endsAt": Timestamp(date: Date.now.addingTimeInterval(Double(minutes * 60)))]) }
            else { try await ref.delete() }
        }
    }

    private func publishPresence() {
        guard let id = activeGroupID, var local = localPresence else { return }
        local.lastSeen = .now; localPresence = local; lastPositionWrite = .now
        do {
            var data = try Firestore.Encoder().encode(local)
            data["lastSeen"] = FieldValue.serverTimestamp()
            let session = local.id
            groupRef(id).collection("presence").document(session).setData(data) { [weak self] error in
                Task { @MainActor [weak self] in
                    guard let self, self.sessionID == session else { return }
                    if let error { self.connection = "Connection unavailable"; self.fail(error) }
                }
            }
        } catch { fail(error) }
    }
    private func groupRef(_ id: String) -> DocumentReference { db.collection("friendHubGroups").document(id) }
    private func save(_ operation: () async throws -> Void) async -> Bool {
        #if DEBUG
        if visualCheck { errorMessage = "This visual preview doesn’t save changes."; return false }
        #endif
        guard !isSaving else { return false }
        isSaving = true; errorMessage = ""
        defer { isSaving = false }
        do { try await operation(); return true } catch { fail(error); return false }
    }
    private func fail(_ error: Error) {
        if (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue {
            errorMessage = "This group is unavailable or your account doesn’t have access. Try again after checking your membership."
        } else { errorMessage = error.localizedDescription }
    }
    private func transaction(_ body: @escaping (Transaction) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, pointer in
                do { try body(transaction) } catch { pointer?.pointee = error as NSError }
                return nil
            }, completion: { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
    }
}

enum FriendGroupError: LocalizedError {
    case invalidAction, gameFull, settingsChanged
    var errorDescription: String? {
        switch self {
        case .settingsChanged: return "Group settings changed while you were editing. Close settings and reopen them to get the latest version."
        case .invalidAction: return "Things changed. Check whose turn it is and try again."
        case .gameFull: return "Two friends are playing. Watch this round, then join the next one."
        }
    }
}
