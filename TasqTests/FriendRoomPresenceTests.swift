import Foundation
import FirebaseFirestore
import Testing
@testable import Tasq

@MainActor
struct FriendRoomPresenceTests {
    private func newlyJoinedPlayer() -> FriendRoomPresence {
        FriendRoomPresence(id: "test-session", userID: "test-user", name: "Player",
            avatar: .fallback, roomID: FriendGroupRoom.lounge.rawValue,
            x: 0.5, y: 0.65, isMoving: false, lastSeen: .now)
    }

    @Test func joiningRoomEncodesWithoutAnOutOfRangeTimestamp() throws {
        let player = newlyJoinedPlayer()
        // Use the actual SDK encoder: JSONEncoder does not reproduce the SDK's
        // Objective-C exception for Date.distantPast, which Swift catch cannot catch.
        let data = try Firestore.Encoder().encode(player)
        let reactionAt = try #require(data["reactionAt"] as? Timestamp)
        #expect(reactionAt.seconds == 0)
        #expect(reactionAt.nanoseconds == 0)
        #expect(player.reaction.isEmpty)
        #expect(Date.now.timeIntervalSince(player.reactionAt) > 5)
        #expect(data["lastSeen"] is Timestamp)
    }

    @Test func movementAndReactionsKeepPresenceEncodable() throws {
        var player = newlyJoinedPlayer()
        player.x = 0.7
        player.isMoving = true
        let moved = try Firestore.Encoder().encode(player)
        #expect((moved["reactionAt"] as? Timestamp)?.seconds == 0)

        player.reaction = "👋"
        player.reactionAt = Date(timeIntervalSince1970: 1_800_000_000)
        let data = try Firestore.Encoder().encode(player)
        let decoded = try Firestore.Decoder().decode(FriendRoomPresence.self, from: data)
        #expect(decoded.reaction == "👋")
        #expect(decoded.reactionAt == player.reactionAt)
        #expect(decoded.x == player.x)
    }
}
