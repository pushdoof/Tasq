import Foundation
import SwiftUI
import FirebaseFirestore
internal import Combine

struct FriendAvatarConfig: Codable, Equatable {
    var bodyColorRaw: String
    var mouthRaw: String
    var eyesRaw: String
    var hairRaw: String
    var furRaw: String
    var itemRaw: String
    var hairHue: Double
    var hairSaturation: Double
    var hairBrightness: Double
    var scarfHue: Double
}

extension FriendAvatarConfig {
    static var fallback: FriendAvatarConfig {
        FriendAvatarConfig(
            bodyColorRaw: FriendAvatarBodyColor.skin7.rawValue,
            mouthRaw: FriendAvatarMouth.none.rawValue,
            eyesRaw: FriendAvatarEyes.none.rawValue,
            hairRaw: FriendAvatarHair.none.rawValue,
            furRaw: FriendAvatarFur.none.rawValue,
            itemRaw: FriendAvatarItem.none.rawValue,
            hairHue: 0.0,
            hairSaturation: 0.72,
            hairBrightness: 0.86,
            scarfHue: 0.78
        )
    }

    var bodyColor: FriendAvatarBodyColor {
        FriendAvatarBodyColor(rawValue: bodyColorRaw) ?? .skin7
    }

    var mouth: FriendAvatarMouth {
        FriendAvatarMouth(rawValue: mouthRaw) ?? .none
    }

    var eyes: FriendAvatarEyes {
        FriendAvatarEyes(rawValue: eyesRaw) ?? .none
    }

    var hair: FriendAvatarHair {
        FriendAvatarHair(rawValue: hairRaw) ?? .none
    }

    var fur: FriendAvatarFur {
        .none
    }

    var item: FriendAvatarItem {
        FriendAvatarItem(rawValue: itemRaw) ?? .none
    }

    var hairColor: Color {
        Color(hue: hairHue, saturation: hairSaturation, brightness: hairBrightness)
    }

    var scarfColor: Color {
        Color(hue: scarfHue, saturation: 0.68, brightness: 0.82)
    }
}

struct FriendHubPlayer: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var avatar: FriendAvatarConfig
    var x: Double
    var y: Double
    var isMoving: Bool
    var lastSeen: Date
}

@MainActor
final class FriendHubMultiplayerStore: ObservableObject {
    @Published private(set) var players: [FriendHubPlayer] = []
    @Published private(set) var connectionStatus = "Local room"

    let localPlayerID: String

    init(userDefaults: UserDefaults = .standard) {
        if let savedID = userDefaults.string(forKey: "friendHubPlayerID") {
            localPlayerID = savedID
        } else {
            let newID = UUID().uuidString
            userDefaults.set(newID, forKey: "friendHubPlayerID")
            localPlayerID = newID
        }
    }

    func join(name: String, avatar: FriendAvatarConfig, x: Double, y: Double) {
        let localPlayer = FriendHubPlayer(
            id: localPlayerID,
            name: name,
            avatar: avatar,
            x: x,
            y: y,
            isMoving: false,
            lastSeen: .now
        )
        upsert(localPlayer)
        connectionStatus = "Local room"
    }

    func updateLocalAvatar(_ avatar: FriendAvatarConfig) {
        guard let index = players.firstIndex(where: { $0.id == localPlayerID }) else { return }
        players[index].avatar = avatar
        players[index].lastSeen = .now
    }

    func updateLocalPosition(x: Double, y: Double, isMoving: Bool) {
        guard let index = players.firstIndex(where: { $0.id == localPlayerID }) else { return }
        players[index].x = x
        players[index].y = y
        players[index].isMoving = isMoving
        players[index].lastSeen = .now
    }

    func leave() {
        players.removeAll { $0.id == localPlayerID }
        connectionStatus = "Disconnected"
    }

    private func upsert(_ player: FriendHubPlayer) {
        if let index = players.firstIndex(where: { $0.id == player.id }) {
            players[index] = player
        } else {
            players.append(player)
        }
    }
}

struct FriendHubAccount: Identifiable, Equatable {
    var id: String
    var username: String
    var displayName: String
    var profileIconName: String
    var profileColorRaw: String
    var bio: String
    var status: String
    var friendIDs: [String]

    var initials: String {
        let source = displayName.isEmpty ? username : displayName
        let value = source.prefix(2).uppercased()
        return value.isEmpty ? "?" : value
    }
}

struct FriendHubFriendRequest: Identifiable, Equatable {
    var id: String
    var senderID: String
    var receiverID: String
    var sender: FriendHubAccount
}

struct FriendHubChatMessage: Identifiable, Equatable {
    var id: String
    var senderID: String
    var text: String
    var imageDataBase64: String?
    var createdAt: Date

    var hasImage: Bool {
        imageDataBase64?.isEmpty == false
    }
}

@MainActor
final class FriendHubSearchStore: ObservableObject {
    @Published var query = ""
    @Published var usernameDraft = ""
    @Published var profileUsernameDraft = ""
    @Published var displayNameDraft = ""
    @Published var profileIconNameDraft = "person.crop.circle.fill"
    @Published var profileColorRawDraft = "blue"
    @Published var bioDraft = ""
    @Published var statusDraft = ""
    @Published private(set) var accounts: [FriendHubAccount] = []
    @Published private(set) var publicAccount: FriendHubAccount?
    @Published private(set) var incomingRequests: [FriendHubFriendRequest] = []
    @Published private(set) var friends: [FriendHubAccount] = []
    @Published var selectedProfile: FriendHubAccount?
    @Published var selectedChatFriend: FriendHubAccount?
    @Published private(set) var selectedProfileFriends: [FriendHubAccount] = []
    @Published private(set) var chatMessages: [FriendHubChatMessage] = []
    @Published private(set) var chatSafetyAccepted = false
    @Published private(set) var chatBlocked = false
    @Published private(set) var isLoadingChat = false
    @Published private(set) var isSendingMessage = false
    @Published private(set) var isSendingPicture = false
    @Published private(set) var isLoadingProfile = false
    @Published private(set) var isCreatingAccount = false
    @Published private(set) var isSavingProfile = false
    @Published private(set) var isLoadingSocialData = false
    @Published private(set) var isSendingFriendRequest = false
    @Published private(set) var isSearching = false
    @Published private(set) var onboardingMessage = "Pick a username so friends can find you."
    @Published private(set) var searchMessage = "Search by username."
    @Published private(set) var profileMessage = ""
    @Published private(set) var notificationsMessage = ""
    @Published private(set) var friendsMessage = ""
    @Published private(set) var selectedProfileMessage = ""
    @Published private(set) var chatMessage = ""

    // This Firebase project uses the named Firestore database "default".
    // Firestore.firestore() targets the special "(default)" database instead.
    private let database = Firestore.firestore(database: "default")
    private var searchTask: Task<Void, Never>?
    private var chatListener: ListenerRegistration?
    private var chatMetadataListener: ListenerRegistration?

    deinit {
        searchTask?.cancel()
        chatListener?.remove()
        chatMetadataListener?.remove()
    }

    var normalizedUsernameDraft: String {
        usernameDraft.friendHubUsernameNormalized
    }

    var canCreateAccount: Bool {
        FriendHubUsernameValidator.validationMessage(for: normalizedUsernameDraft) == nil && !isCreatingAccount
    }

    var normalizedProfileUsernameDraft: String {
        profileUsernameDraft.friendHubUsernameNormalized
    }

    var canSaveProfile: Bool {
        FriendHubUsernameValidator.validationMessage(for: normalizedProfileUsernameDraft) == nil && !isSavingProfile
    }

    func loadPublicAccount(for userID: String?) async {
        guard let userID else {
            publicAccount = nil
            return
        }

        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            let document = try await profileDocument(for: userID).getDocument()
            guard let data = document.data(),
                  let username = data["username"] as? String,
                  !username.isEmpty else {
                publicAccount = nil
                return
            }

            let account = account(from: document.documentID, data: data, username: username)
            publicAccount = account
            applyProfileDrafts(from: account)
            await loadSocialData(for: userID)
        } catch {
            onboardingMessage = friendHubMessage(for: error)
        }
    }

    func createPublicAccount(for userID: String?) async {
        guard let userID else {
            onboardingMessage = "Sign in before creating a Friend Hub username."
            return
        }

        let normalizedUsername = normalizedUsernameDraft
        if let validationMessage = FriendHubUsernameValidator.validationMessage(for: normalizedUsername) {
            onboardingMessage = validationMessage
            return
        }

        isCreatingAccount = true
        onboardingMessage = ""
        defer { isCreatingAccount = false }

        do {
            try await reserve(username: normalizedUsername, for: userID)
            let account = FriendHubAccount(
                id: userID,
                username: normalizedUsername,
                displayName: normalizedUsername,
                profileIconName: profileIconNameDraft,
                profileColorRaw: profileColorRawDraft,
                bio: "",
                status: "",
                friendIDs: []
            )
            publicAccount = account
            applyProfileDrafts(from: account)
            await loadSocialData(for: userID)
            usernameDraft = ""
            onboardingMessage = ""
        } catch {
            onboardingMessage = friendHubMessage(for: error)
        }
    }

    func saveProfileSettings(for userID: String?) async {
        guard let userID else {
            profileMessage = "Sign in before editing your Friend Hub profile."
            return
        }

        let username = normalizedProfileUsernameDraft
        if let validationMessage = FriendHubUsernameValidator.validationMessage(for: username) {
            profileMessage = validationMessage
            return
        }

        let displayName = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedDisplayName = displayName.isEmpty ? username : String(displayName.prefix(32))
        let iconName = profileIconNameDraft
        let colorRaw = profileColorRawDraft
        let bio = String(bioDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(90))
        let status = String(statusDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))

        isSavingProfile = true
        profileMessage = ""
        defer { isSavingProfile = false }

        do {
            try await saveProfile(
                username: username,
                displayName: savedDisplayName,
                iconName: iconName,
                colorRaw: colorRaw,
                bio: bio,
                status: status,
                for: userID
            )

            let account = FriendHubAccount(
                id: userID,
                username: username,
                displayName: savedDisplayName,
                profileIconName: iconName,
                profileColorRaw: colorRaw,
                bio: bio,
                status: status,
                friendIDs: publicAccount?.friendIDs ?? []
            )
            publicAccount = account
            applyProfileDrafts(from: account)
            profileMessage = "Profile saved."
            if !query.isEmpty {
                scheduleSearch(excluding: userID)
            }
        } catch {
            profileMessage = friendHubMessage(for: error)
        }
    }

    func loadSocialData(for userID: String?) async {
        guard let userID else { return }

        isLoadingSocialData = true
        defer { isLoadingSocialData = false }

        do {
            async let incoming = loadIncomingRequests(for: userID)
            async let friendAccounts = loadFriendAccounts(for: publicAccount?.friendIDs ?? [])
            incomingRequests = try await incoming
            friends = try await friendAccounts
            notificationsMessage = incomingRequests.isEmpty ? "No friend requests." : ""
            friendsMessage = friends.isEmpty ? "Your friends will show up here." : ""
        } catch {
            let message = friendHubMessage(for: error)
            notificationsMessage = message
            friendsMessage = message
        }
    }

    func selectProfile(_ account: FriendHubAccount, currentUserID: String?) async {
        selectedProfile = account
        selectedProfileFriends = []
        selectedProfileMessage = ""

        do {
            let document = try await profileDocument(for: account.id).getDocument()
            guard let data = document.data(),
                  let username = data["username"] as? String,
                  !username.isEmpty else {
                selectedProfileMessage = "This profile is no longer available."
                return
            }

            let freshAccount = self.account(from: document.documentID, data: data, username: username)
            selectedProfile = freshAccount
            selectedProfileFriends = try await loadFriendAccounts(for: freshAccount.friendIDs)
        } catch {
            selectedProfileMessage = friendHubMessage(for: error)
        }
    }

    func sendFriendRequest(to account: FriendHubAccount, from currentUserID: String?) async {
        guard let currentUserID, let publicAccount else {
            selectedProfileMessage = "Create your Friend Hub profile before sending friend requests."
            return
        }

        guard currentUserID != account.id else { return }

        if publicAccount.friendIDs.contains(account.id) {
            selectedProfileMessage = "You are already friends."
            return
        }

        isSendingFriendRequest = true
        selectedProfileMessage = ""
        defer { isSendingFriendRequest = false }

        do {
            try await createFriendRequest(from: publicAccount, to: account)
            selectedProfileMessage = "Friend request sent."
        } catch {
            selectedProfileMessage = friendHubMessage(for: error)
        }
    }

    func acceptFriendRequest(_ request: FriendHubFriendRequest, currentUserID: String?) async {
        guard let currentUserID else { return }

        do {
            try await accept(request: request, currentUserID: currentUserID)
            await refreshCurrentProfileAndSocialData(for: currentUserID)
        } catch {
            notificationsMessage = friendHubMessage(for: error)
        }
    }

    func declineFriendRequest(_ request: FriendHubFriendRequest, currentUserID: String?) async {
        guard currentUserID != nil else { return }

        do {
            try await requestDocument(for: request.id).delete()
            incomingRequests.removeAll { $0.id == request.id }
            notificationsMessage = incomingRequests.isEmpty ? "No friend requests." : ""
        } catch {
            notificationsMessage = friendHubMessage(for: error)
        }
    }

    func openChat(with friend: FriendHubAccount, currentUserID: String?) {
        guard let currentUserID,
              publicAccount?.friendIDs.contains(friend.id) == true else {
            chatMessage = "You can only chat with friends."
            return
        }

        chatListener?.remove()
        chatMetadataListener?.remove()
        selectedChatFriend = friend
        chatMessages = []
        chatMessage = ""
        chatSafetyAccepted = hasAcceptedChatSafety(with: friend.id)
        chatBlocked = false
        isLoadingChat = true

        let chatID = chatID(for: currentUserID, and: friend.id)
        chatMetadataListener = chatDocument(for: chatID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.chatMessage = self.friendHubMessage(for: error)
                        return
                    }

                    let isBlocked = snapshot?.data()?["isBlocked"] as? Bool ?? false
                    self.chatBlocked = isBlocked
                    if isBlocked {
                        self.chatMessage = "This chat was blocked after an inappropriate picture report."
                    } else if self.chatMessage.contains("blocked") {
                        self.chatMessage = ""
                    }
                }
            }

        chatListener = chatMessagesCollection(for: chatID)
            .order(by: "createdAt", descending: false)
            .limit(toLast: 80)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoadingChat = false

                    if let error {
                        self.chatMessage = self.friendHubMessage(for: error)
                        return
                    }

                    self.chatMessages = snapshot?.documents.compactMap { document in
                        let data = document.data()
                        guard let senderID = data["senderID"] as? String else {
                            return nil
                        }

                        let text = data["text"] as? String ?? ""
                        let imageDataBase64 = data["imageDataBase64"] as? String
                        guard !text.isEmpty || imageDataBase64?.isEmpty == false else {
                            return nil
                        }

                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? .now
                        return FriendHubChatMessage(
                            id: document.documentID,
                            senderID: senderID,
                            text: text,
                            imageDataBase64: imageDataBase64,
                            createdAt: createdAt
                        )
                    } ?? []
                }
            }
    }

    func closeChat() {
        chatListener?.remove()
        chatMetadataListener?.remove()
        chatListener = nil
        chatMetadataListener = nil
        selectedChatFriend = nil
        chatMessages = []
        chatMessage = ""
        chatBlocked = false
        isLoadingChat = false
        isSendingMessage = false
        isSendingPicture = false
    }

    func acceptChatSafety(for friendID: String) {
        UserDefaults.standard.set(FriendHubChatSafety.currentSafetyVersion, forKey: chatSafetyKey(for: friendID))
        chatSafetyAccepted = true
        chatMessage = ""
    }

    func sendChatMessage(_ text: String, currentUserID: String?) async -> Bool {
        guard let currentUserID,
              let publicAccount,
              let selectedChatFriend else {
            chatMessage = "Open a friend chat before sending a message."
            return false
        }

        guard publicAccount.friendIDs.contains(selectedChatFriend.id) else {
            chatMessage = "You can only chat with friends."
            return false
        }

        guard chatSafetyAccepted else {
            chatMessage = "Read and accept the chat safety reminders first."
            return false
        }

        guard !chatBlocked else {
            chatMessage = "This chat is blocked."
            return false
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let safetyMessage = FriendHubChatSafety.validationMessage(for: trimmedText) {
            chatMessage = safetyMessage
            return false
        }

        isSendingMessage = true
        chatMessage = ""
        defer { isSendingMessage = false }

        do {
            let chatID = chatID(for: currentUserID, and: selectedChatFriend.id)
            guard try await !isChatBlocked(chatID: chatID) else {
                chatBlocked = true
                chatMessage = "This chat is blocked."
                return false
            }

            try await chatDocument(for: chatID).setData([
                "participantIDs": [currentUserID, selectedChatFriend.id],
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            try await chatMessagesCollection(for: chatID).addDocument(data: [
                "senderID": currentUserID,
                "senderUsername": publicAccount.username,
                "text": trimmedText,
                "createdAt": FieldValue.serverTimestamp()
            ])

            return true
        } catch {
            chatMessage = friendHubMessage(for: error)
            return false
        }
    }

    func sendChatPicture(_ imageData: Data, currentUserID: String?) async -> Bool {
        guard let currentUserID,
              let publicAccount,
              let selectedChatFriend else {
            chatMessage = "Open a friend chat before sending a picture."
            return false
        }

        guard publicAccount.friendIDs.contains(selectedChatFriend.id) else {
            chatMessage = "You can only chat with friends."
            return false
        }

        guard chatSafetyAccepted else {
            chatMessage = "Read and accept the chat safety reminders first."
            return false
        }

        guard !chatBlocked else {
            chatMessage = "This chat is blocked."
            return false
        }

        if let safetyMessage = FriendHubChatSafety.validationMessage(forImageData: imageData) {
            chatMessage = safetyMessage
            return false
        }

        isSendingPicture = true
        chatMessage = ""
        defer { isSendingPicture = false }

        do {
            let chatID = chatID(for: currentUserID, and: selectedChatFriend.id)
            guard try await !isChatBlocked(chatID: chatID) else {
                chatBlocked = true
                chatMessage = "This chat is blocked."
                return false
            }

            try await chatDocument(for: chatID).setData([
                "participantIDs": [currentUserID, selectedChatFriend.id],
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            try await chatMessagesCollection(for: chatID).addDocument(data: [
                "senderID": currentUserID,
                "senderUsername": publicAccount.username,
                "text": "",
                "imageDataBase64": imageData.base64EncodedString(),
                "contentType": "image/jpeg",
                "createdAt": FieldValue.serverTimestamp()
            ])

            return true
        } catch {
            chatMessage = friendHubMessage(for: error)
            return false
        }
    }

    func reportInappropriatePicture(_ message: FriendHubChatMessage, currentUserID: String?) async {
        guard let currentUserID,
              let selectedChatFriend,
              message.hasImage else {
            chatMessage = "Open an image chat before reporting."
            return
        }

        let chatID = chatID(for: currentUserID, and: selectedChatFriend.id)

        do {
            try await chatDocument(for: chatID).setData([
                "participantIDs": [currentUserID, selectedChatFriend.id],
                "isBlocked": true,
                "blockedAt": FieldValue.serverTimestamp(),
                "blockedBy": currentUserID,
                "blockedMessageID": message.id,
                "blockReason": "reported_inappropriate_image",
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            chatBlocked = true
            chatMessage = "This chat was blocked after an inappropriate picture report."
        } catch {
            chatMessage = friendHubMessage(for: error)
        }
    }

    func scheduleSearch(excluding currentUserID: String?) {
        searchTask?.cancel()

        let normalizedQuery = query.friendHubUsernameNormalized
        guard normalizedQuery.count >= 2 else {
            accounts = []
            isSearching = false
            searchMessage = normalizedQuery.isEmpty ? "Search by username." : "Type at least 2 characters."
            return
        }

        isSearching = true
        searchMessage = ""

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await self?.performSearch(for: normalizedQuery, excluding: currentUserID)
        }
    }

    private func reserve(username: String, for userID: String) async throws {
        let usernameDocument = usernameDocument(for: username)
        let profileDocument = profileDocument(for: userID)
        let usernameKeywords = searchKeywords(for: username)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction { transaction, errorPointer in
                do {
                    let existingUsername = try transaction.getDocument(usernameDocument)
                    if existingUsername.exists {
                        errorPointer?.pointee = FriendHubPublicAccountError.usernameTaken as NSError
                        return nil
                    }

                    let existingProfile = try transaction.getDocument(profileDocument)
                    if let existingUsername = existingProfile.data()?["username"] as? String,
                       !existingUsername.isEmpty {
                        errorPointer?.pointee = FriendHubPublicAccountError.accountAlreadyCreated as NSError
                        return nil
                    }

                    transaction.setData([
                        "userID": userID,
                        "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: usernameDocument)

                    transaction.setData([
                        "username": username,
                        "normalizedUsername": username,
                        "usernameKeywords": usernameKeywords,
                        "displayName": username,
                        "profileIconName": "person.crop.circle.fill",
                        "profileColorRaw": "blue",
                        "bio": "",
                        "status": "",
                        "friendIDs": [],
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: profileDocument)

                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            } completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func saveProfile(
        username: String,
        displayName: String,
        iconName: String,
        colorRaw: String,
        bio: String,
        status: String,
        for userID: String
    ) async throws {
        let profileDocument = profileDocument(for: userID)
        let newUsernameDocument = usernameDocument(for: username)
        let usernameKeywords = searchKeywords(for: username)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction { transaction, errorPointer in
                do {
                    let existingProfile = try transaction.getDocument(profileDocument)
                    guard existingProfile.exists else {
                        errorPointer?.pointee = FriendHubPublicAccountError.profileMissing as NSError
                        return nil
                    }

                    let oldUsername = existingProfile.data()?["username"] as? String ?? ""
                    if username != oldUsername {
                        let existingUsername = try transaction.getDocument(newUsernameDocument)
                        if existingUsername.exists,
                           existingUsername.data()?["userID"] as? String != userID {
                            errorPointer?.pointee = FriendHubPublicAccountError.usernameTaken as NSError
                            return nil
                        }

                        if !oldUsername.isEmpty {
                            transaction.deleteDocument(self.usernameDocument(for: oldUsername))
                        }

                        transaction.setData([
                            "userID": userID,
                            "createdAt": FieldValue.serverTimestamp()
                        ], forDocument: newUsernameDocument)
                    }

                    transaction.setData([
                        "username": username,
                        "normalizedUsername": username,
                        "usernameKeywords": usernameKeywords,
                        "displayName": displayName,
                        "profileIconName": iconName,
                        "profileColorRaw": colorRaw,
                        "bio": bio,
                        "status": status,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: profileDocument, merge: true)

                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            } completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func createFriendRequest(from sender: FriendHubAccount, to receiver: FriendHubAccount) async throws {
        let friendRequestID = requestID(from: sender.id, to: receiver.id)
        let reverseFriendRequestID = requestID(from: receiver.id, to: sender.id)
        let friendRequestDocument = requestDocument(for: friendRequestID)
        let reverseFriendRequestDocument = requestDocument(for: reverseFriendRequestID)
        let senderProfileDocument = profileDocument(for: sender.id)
        let receiverProfileDocument = profileDocument(for: receiver.id)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction { transaction, errorPointer in
                do {
                    let senderProfile = try transaction.getDocument(senderProfileDocument)
                    let receiverProfile = try transaction.getDocument(receiverProfileDocument)
                    let existingRequest = try transaction.getDocument(friendRequestDocument)
                    let existingReverseRequest = try transaction.getDocument(reverseFriendRequestDocument)

                    let senderFriendIDs = senderProfile.data()?["friendIDs"] as? [String] ?? []
                    let receiverFriendIDs = receiverProfile.data()?["friendIDs"] as? [String] ?? []
                    if senderFriendIDs.contains(receiver.id) || receiverFriendIDs.contains(sender.id) {
                        errorPointer?.pointee = FriendHubPublicAccountError.alreadyFriends as NSError
                        return nil
                    }

                    if existingRequest.exists {
                        errorPointer?.pointee = FriendHubPublicAccountError.requestAlreadySent as NSError
                        return nil
                    }

                    if existingReverseRequest.exists {
                        errorPointer?.pointee = FriendHubPublicAccountError.requestAlreadyReceived as NSError
                        return nil
                    }

                    transaction.setData([
                        "senderID": sender.id,
                        "receiverID": receiver.id,
                        "senderUsername": sender.username,
                        "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: friendRequestDocument)

                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            } completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func accept(request: FriendHubFriendRequest, currentUserID: String) async throws {
        let requestDocument = requestDocument(for: request.id)
        let senderProfileDocument = profileDocument(for: request.senderID)
        let receiverProfileDocument = profileDocument(for: currentUserID)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction { transaction, errorPointer in
                do {
                    let requestSnapshot = try transaction.getDocument(requestDocument)
                    guard requestSnapshot.exists,
                          requestSnapshot.data()?["receiverID"] as? String == currentUserID else {
                        errorPointer?.pointee = FriendHubPublicAccountError.requestMissing as NSError
                        return nil
                    }

                    transaction.updateData([
                        "friendIDs": FieldValue.arrayUnion([request.senderID]),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: receiverProfileDocument)

                    transaction.updateData([
                        "friendIDs": FieldValue.arrayUnion([currentUserID]),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: senderProfileDocument)

                    transaction.deleteDocument(requestDocument)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            } completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func loadIncomingRequests(for userID: String) async throws -> [FriendHubFriendRequest] {
        let snapshot = try await database.collection("friendHubFriendRequests")
            .whereField("receiverID", isEqualTo: userID)
            .limit(to: 50)
            .getDocuments()

        var requests: [FriendHubFriendRequest] = []
        for document in snapshot.documents {
            let data = document.data()
            guard let senderID = data["senderID"] as? String,
                  let receiverID = data["receiverID"] as? String else {
                continue
            }

            let senderDocument = try await profileDocument(for: senderID).getDocument()
            guard let senderData = senderDocument.data(),
                  let username = senderData["username"] as? String,
                  !username.isEmpty else {
                continue
            }

            requests.append(
                FriendHubFriendRequest(
                    id: document.documentID,
                    senderID: senderID,
                    receiverID: receiverID,
                    sender: account(from: senderID, data: senderData, username: username)
                )
            )
        }

        return requests.sorted {
            $0.sender.username.localizedCaseInsensitiveCompare($1.sender.username) == .orderedAscending
        }
    }

    private func loadFriendAccounts(for friendIDs: [String]) async throws -> [FriendHubAccount] {
        var loadedFriends: [FriendHubAccount] = []
        for friendID in friendIDs {
            let document = try await profileDocument(for: friendID).getDocument()
            guard let data = document.data(),
                  let username = data["username"] as? String,
                  !username.isEmpty else {
                continue
            }

            loadedFriends.append(account(from: friendID, data: data, username: username))
        }

        return loadedFriends.sorted {
            $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending
        }
    }

    private func refreshCurrentProfileAndSocialData(for userID: String) async {
        do {
            let document = try await profileDocument(for: userID).getDocument()
            if let data = document.data(),
               let username = data["username"] as? String,
               !username.isEmpty {
                let account = account(from: userID, data: data, username: username)
                publicAccount = account
                applyProfileDrafts(from: account)
            }
            await loadSocialData(for: userID)
        } catch {
            notificationsMessage = friendHubMessage(for: error)
        }
    }

    private func performSearch(for normalizedQuery: String, excluding currentUserID: String?) async {
        do {
            let snapshot = try await database.collection("friendHubProfiles")
                .whereField("usernameKeywords", arrayContains: normalizedQuery)
                .limit(to: 20)
                .getDocuments()

            let matchingAccounts = snapshot.documents.compactMap { document -> FriendHubAccount? in
                guard document.documentID != currentUserID else { return nil }

                let data = document.data()
                guard let username = data["username"] as? String, !username.isEmpty else {
                    return nil
                }

                return account(from: document.documentID, data: data, username: username)
            }

            accounts = matchingAccounts.sorted {
                $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending
            }
            searchMessage = accounts.isEmpty ? "No accounts found." : ""
        } catch {
            accounts = []
            searchMessage = friendHubMessage(for: error)
        }

        isSearching = false
    }

    private func friendHubMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("firestore.googleapis.com") ||
            message.localizedCaseInsensitiveContains("Cloud Firestore API") {
            return "Friend Hub needs Cloud Firestore enabled for Firebase project tasq-30132."
        }

        if message.localizedCaseInsensitiveContains("database (default) does not exist") {
            return "Friend Hub needs a default Cloud Firestore database created for project tasq-30132."
        }

        if message.localizedCaseInsensitiveContains("offline") {
            return "Friend Hub cannot reach Firestore. Check that Cloud Firestore is enabled for project tasq-30132, then try again."
        }

        if message.localizedCaseInsensitiveContains("Missing or insufficient permissions") {
            return "Friend Hub needs Firestore rules that allow signed-in users to create profiles and search usernames."
        }

        return message
    }

    private func profileDocument(for userID: String) -> DocumentReference {
        database.collection("friendHubProfiles").document(userID)
    }

    private func usernameDocument(for username: String) -> DocumentReference {
        database.collection("friendHubUsernames").document(username)
    }

    private func searchKeywords(for username: String) -> [String] {
        guard username.count >= 2 else { return [] }
        return (2...username.count).map { String(username.prefix($0)) }
    }

    private func account(from id: String, data: [String: Any], username: String) -> FriendHubAccount {
        FriendHubAccount(
            id: id,
            username: username,
            displayName: data["displayName"] as? String ?? username,
            profileIconName: data["profileIconName"] as? String ?? "person.crop.circle.fill",
            profileColorRaw: data["profileColorRaw"] as? String ?? "blue",
            bio: data["bio"] as? String ?? "",
            status: data["status"] as? String ?? "",
            friendIDs: data["friendIDs"] as? [String] ?? []
        )
    }

    private func applyProfileDrafts(from account: FriendHubAccount) {
        profileUsernameDraft = account.username
        displayNameDraft = account.displayName
        profileIconNameDraft = account.profileIconName
        profileColorRawDraft = account.profileColorRaw
        bioDraft = account.bio
        statusDraft = account.status
    }

    private func requestID(from senderID: String, to receiverID: String) -> String {
        "\(senderID)_\(receiverID)"
    }

    private func requestDocument(for requestID: String) -> DocumentReference {
        database.collection("friendHubFriendRequests").document(requestID)
    }

    private func chatID(for firstUserID: String, and secondUserID: String) -> String {
        [firstUserID, secondUserID].sorted().joined(separator: "_")
    }

    private func chatDocument(for chatID: String) -> DocumentReference {
        database.collection("friendHubChats").document(chatID)
    }

    private func chatMessagesCollection(for chatID: String) -> CollectionReference {
        chatDocument(for: chatID).collection("messages")
    }

    private func isChatBlocked(chatID: String) async throws -> Bool {
        let document = try await chatDocument(for: chatID).getDocument()
        return document.data()?["isBlocked"] as? Bool ?? false
    }

    private func hasAcceptedChatSafety(with friendID: String) -> Bool {
        UserDefaults.standard.integer(forKey: chatSafetyKey(for: friendID)) >= FriendHubChatSafety.currentSafetyVersion
    }

    private func chatSafetyKey(for friendID: String) -> String {
        "friendHubChatSafetyAccepted_\(friendID)"
    }
}

enum FriendHubPublicAccountError: LocalizedError {
    case usernameTaken
    case accountAlreadyCreated
    case profileMissing
    case alreadyFriends
    case requestAlreadySent
    case requestAlreadyReceived
    case requestMissing

    var errorDescription: String? {
        switch self {
        case .usernameTaken:
            return "That username is already taken."
        case .accountAlreadyCreated:
            return "This account already has a Friend Hub username."
        case .profileMissing:
            return "Create a Friend Hub username before editing your profile."
        case .alreadyFriends:
            return "You are already friends."
        case .requestAlreadySent:
            return "Friend request already sent."
        case .requestAlreadyReceived:
            return "They already sent you a friend request."
        case .requestMissing:
            return "That friend request is no longer available."
        }
    }
}

enum FriendHubUsernameValidator {
    static func validationMessage(for username: String) -> String? {
        guard username.count >= 3 else {
            return "Usernames need at least 3 characters."
        }

        guard username.count <= 20 else {
            return "Usernames can be up to 20 characters."
        }

        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        guard username.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return "Use only letters, numbers, and underscores."
        }

        return nil
    }
}

enum FriendHubChatSafety {
    static let currentSafetyVersion = 2
    static let maxImageDataBytes = 650_000

    static func validationMessage(for message: String) -> String? {
        guard !message.isEmpty else {
            return "Type a message first."
        }

        guard message.count <= 500 else {
            return "Messages can be up to 500 characters."
        }

        let lowercased = message.lowercased()
        let blockedPhrases = [
            "gift card",
            "cash app",
            "venmo",
            "paypal",
            "wire transfer",
            "bank account",
            "password",
            "verification code",
            "home address",
            "where do you live",
            "meet alone",
            "send pics",
            "send photos",
            "keep this secret",
            "don't tell your parents",
            "dont tell your parents"
        ]

        if blockedPhrases.contains(where: { lowercased.contains($0) }) {
            return "That message was blocked for safety. Do not ask for money, secrets, addresses, private photos, passwords, or private meetups."
        }

        if lowercased.contains("http://") || lowercased.contains("https://") || lowercased.contains("www.") {
            return "Links are blocked in Friend Hub chats for safety."
        }

        if message.range(of: #"\b[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}\b"#, options: .regularExpression) != nil {
            return "Email addresses are blocked in Friend Hub chats for safety."
        }

        if message.range(of: #"\b(?:\d[\s.-]?){7,}\b"#, options: .regularExpression) != nil {
            return "Phone numbers and long number strings are blocked in Friend Hub chats for safety."
        }

        return nil
    }

    static func validationMessage(forImageData imageData: Data) -> String? {
        guard !imageData.isEmpty else {
            return "Choose a picture first."
        }

        guard imageData.count <= maxImageDataBytes else {
            return "That picture is too large to send. Try a smaller one."
        }

        return nil
    }
}

private extension String {
    var friendHubUsernameNormalized: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
