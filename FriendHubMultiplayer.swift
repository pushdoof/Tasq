import Foundation
import SwiftUI

struct FriendAvatarConfig: Codable, Equatable {
    var bodyColorRaw: String
    var mouthRaw: String
    var eyesRaw: String
    var hairRaw: String
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

    private var roomTask: Task<Void, Never>?
    private let previewFriendID = "local-preview-friend"

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
        addPreviewFriendIfNeeded()
        connectionStatus = "Local room"
        startPreviewLoop()
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
        roomTask?.cancel()
        roomTask = nil
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

    private func addPreviewFriendIfNeeded() {
        guard !players.contains(where: { $0.id == previewFriendID }) else { return }

        let previewAvatar = FriendAvatarConfig(
            bodyColorRaw: FriendAvatarBodyColor.skin8.rawValue,
            mouthRaw: FriendAvatarMouth.mouth13.rawValue,
            eyesRaw: FriendAvatarEyes.eyes31.rawValue,
            hairRaw: FriendAvatarHair.none.rawValue,
            itemRaw: FriendAvatarItem.none.rawValue,
            hairHue: 0.08,
            hairSaturation: 0.64,
            hairBrightness: 0.34,
            scarfHue: 0.36
        )
        let previewFriend = FriendHubPlayer(
            id: previewFriendID,
            name: "Friend",
            avatar: previewAvatar,
            x: 0.30,
            y: 0.62,
            isMoving: false,
            lastSeen: .now
        )
        players.append(previewFriend)
    }

    private func startPreviewLoop() {
        guard roomTask == nil else { return }

        roomTask = Task { [weak self] in
            var goingRight = true
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                await MainActor.run {
                    self?.movePreviewFriend(goingRight: goingRight)
                }
                goingRight.toggle()
            }
        }
    }

    private func movePreviewFriend(goingRight: Bool) {
        guard let index = players.firstIndex(where: { $0.id == previewFriendID }) else { return }
        players[index].x = goingRight ? 0.38 : 0.30
        players[index].y = goingRight ? 0.58 : 0.62
        players[index].isMoving = true
        players[index].lastSeen = .now

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                guard let self, let index = self.players.firstIndex(where: { $0.id == self.previewFriendID }) else { return }
                self.players[index].isMoving = false
            }
        }
    }
}
