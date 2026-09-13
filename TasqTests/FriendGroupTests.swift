import Foundation
import Testing
@testable import Tasq

struct FriendGroupTests {
    @Test func gamesRequireTwoPlayersAndCorrectTurn() {
        var game = FriendGroupGame()
        game.xID = "a"
        let move1 = game.play(at: 0, userID: "a")

        #expect(!move1)
        game.oID = "b"
        let move2 = game.play(at: 0, userID: "b")

        #expect(!move2)
        let move3 = game.play(at: 0, userID: "a")

        #expect(move3)
        let move4 = game.play(at: 0, userID: "b")

        #expect(!move4)
        let move5 = game.play(at: 1, userID: "outsider")

        #expect(!move5)
        let move6 = game.play(at: -1, userID: "b")

        #expect(!move6)
        let move7 = game.play(at: 9, userID: "b")

        #expect(!move7)
        let move8 = game.play(at: 1, userID: "b")

        #expect(move8)
    }
    @Test func winningRoundRejectsFurtherMoves() {
        var game = FriendGroupGame(xID: "a", oID: "b")
        for (cell, player) in [(0,"a"), (3,"b"), (1,"a"), (4,"b"), (2,"a")] {
            let move9 = game.play(at: cell, userID: player)

            #expect(move9)
        }
        #expect(game.winner == "X")
        let move10 = game.play(at: 5, userID: "b")

        #expect(!move10)
        #expect(FriendGroupGame(board: ["X","O","X","X","O","O","O","X","X"]).winner == "Draw")
    }
    @Test func disabledRoomsAreRemovedButLoungeAlwaysRemains() {
        var group = FriendGroup(id: "g", name: "Group", adminID: "a", memberIDs: ["a"], memberNames: ["a":"A"], createdAt: .now)
        #expect(group.rooms == [.lounge, .quiet, .arcade])
        group.gamesEnabled = false; group.focusEnabled = false
        #expect(group.rooms == [.lounge])
        #expect(!group.contains("outsider"))
    }
    @Test func bubblesSettleWithinBoundsWithoutOverlapping() {
        var physics = FriendBubblePhysics()
        physics.arrange(ids: ["a","b","c","d"], width: 360, height: 480)
        for _ in 0..<600 { physics.step(width: 360, height: 480, dragging: nil) }
        for bubble in physics.bubbles {
            #expect(bubble.x >= bubble.radius && bubble.x <= 360 - bubble.radius)
            #expect(bubble.y >= bubble.radius && bubble.y <= 480 - bubble.radius)
            for other in physics.bubbles where bubble.id != other.id {
                #expect(hypot(bubble.x - other.x, bubble.y - other.y) >= bubble.radius + other.radius - 1)
            }
        }
    }
    @Test func bubblesRecoverAfterFlingAndResize() {
        var physics = FriendBubblePhysics()
        physics.arrange(ids: ["a","b"], width: 360, height: 400)
        physics.drag(id: "a", x: -200, y: 900, vx: -9999, vy: 9999)
        physics.step(width: 360, height: 400, dragging: nil)
        #expect(physics.bubbles[0].x >= physics.bubbles[0].radius)
        #expect(physics.bubbles[0].y <= 400 - physics.bubbles[0].radius)
        physics.arrange(ids: ["a","c"], width: 280, height: 400)
        #expect(physics.bubbles.map(\.id) == ["a","c"])
    }
}
