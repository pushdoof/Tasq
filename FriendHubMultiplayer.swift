import Foundation
import SwiftUI
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
