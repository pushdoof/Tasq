import Foundation

struct FriendGroup: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var adminID: String
    var memberIDs: [String]
    var memberNames: [String: String]
    var gamesEnabled: Bool = true
    var focusEnabled: Bool = true
    var createdAt: Date

    func contains(_ userID: String) -> Bool { memberIDs.contains(userID) }
    var rooms: [FriendGroupRoom] {
        [.lounge] + (focusEnabled ? [.quiet] : []) + (gamesEnabled ? [.arcade] : [])
    }
}

enum FriendGroupRoom: String, CaseIterable, Identifiable, Codable {
    case lounge, quiet, arcade
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lounge: return "Lounge"
        case .quiet: return "Quiet room"
        case .arcade: return "Arcade"
        }
    }
    var subtitle: String {
        switch self {
        case .lounge: return "A little space for your people."
        case .quiet: return "Different tasks. A little company."
        case .arcade: return "Take a playful little break."
        }
    }
    var icon: String {
        switch self {
        case .lounge: return "bubble.left.and.bubble.right"
        case .quiet: return "leaf"
        case .arcade: return "gamecontroller"
        }
    }
}

struct FriendGroupMessage: Identifiable, Codable, Equatable {
    var id: String
    var senderID: String
    var senderName: String
    var text: String
    var createdAt: Date
}

struct FriendGroupGame: Codable, Equatable {
    var board: [String] = Array(repeating: "", count: 9)
    var xID = ""
    var oID = ""
    var turn = "X"

    var winner: String? {
        guard board.count == 9 else { return nil }
        for line in [[0,1,2], [3,4,5], [6,7,8], [0,3,6], [1,4,7], [2,5,8], [0,4,8], [2,4,6]] {
            let mark = board[line[0]]
            if !mark.isEmpty && line.allSatisfy({ board[$0] == mark }) { return mark }
        }
        return board.contains("") ? nil : "Draw"
    }
    var currentPlayerID: String { turn == "X" ? xID : oID }
    mutating func play(at index: Int, userID: String) -> Bool {
        guard board.count == 9, board.indices.contains(index), board[index].isEmpty,
              winner == nil, !xID.isEmpty, !oID.isEmpty, currentPlayerID == userID else { return false }
        board[index] = turn
        turn = turn == "X" ? "O" : "X"
        return true
    }
}

/// Fixed-step gravity, damping and circle collision resolution. Independent of the UI.
struct FriendBubblePhysics {
    struct Bubble: Identifiable {
        var id: String
        var x: Double
        var y: Double
        var radius: Double
        var vx: Double = 0
        var vy: Double = 0
    }
    var bubbles: [Bubble] = []

    mutating func arrange(ids: [String], width: Double, height: Double) {
        guard width > 0, height > 0 else { return }
        let radius = min(86, max(44, (width - 38) / 4))
        bubbles = ids.enumerated().map { index, id in
            if let old = bubbles.first(where: { $0.id == id }) {
                return Bubble(id: id, x: min(width - radius, max(radius, old.x)),
                              y: min(height - radius, max(radius, old.y)), radius: radius)
            }
            return Bubble(id: id, x: width * (index % 2 == 0 ? 0.27 : 0.73),
                          y: radius + 14 + Double(index / 2) * (radius * 2 + 14), radius: radius)
        }
    }

    mutating func step(width: Double, height: Double, dragging: String?) {
        let dt = 1.0 / 30
        for i in bubbles.indices where bubbles[i].id != dragging {
            bubbles[i].vx += (width / 2 - bubbles[i].x) * 0.18 * dt
            bubbles[i].vy += 105 * dt
            bubbles[i].vx *= 0.985
            bubbles[i].vy *= 0.985
            bubbles[i].x += bubbles[i].vx * dt
            bubbles[i].y += bubbles[i].vy * dt
        }
        // A few solver passes keep piles stable and prevent overlapping bubbles.
        for _ in 0..<4 {
            for i in bubbles.indices {
                for j in bubbles.indices where j > i {
                    let dx = bubbles[j].x - bubbles[i].x
                    let dy = bubbles[j].y - bubbles[i].y
                    let distance = max(0.001, hypot(dx, dy))
                    let overlap = bubbles[i].radius + bubbles[j].radius + 8 - distance
                    guard overlap > 0 else { continue }
                    let nx = distance <= 0.001 ? 1 : dx / distance
                    let ny = distance <= 0.001 ? 0 : dy / distance
                    let moveI = bubbles[i].id != dragging
                    let moveJ = bubbles[j].id != dragging
                    let share = moveI && moveJ ? 0.5 : 1.0
                    if moveI { bubbles[i].x -= nx * overlap * share; bubbles[i].y -= ny * overlap * share }
                    if moveJ { bubbles[j].x += nx * overlap * share; bubbles[j].y += ny * overlap * share }
                    let speed = (bubbles[j].vx - bubbles[i].vx) * nx + (bubbles[j].vy - bubbles[i].vy) * ny
                    if speed < 0 {
                        if moveI { bubbles[i].vx += speed * nx * 0.6; bubbles[i].vy += speed * ny * 0.6 }
                        if moveJ { bubbles[j].vx -= speed * nx * 0.6; bubbles[j].vy -= speed * ny * 0.6 }
                    }
                }
                let r = bubbles[i].radius + 4
                if bubbles[i].x < r { bubbles[i].x = r; bubbles[i].vx = abs(bubbles[i].vx) * 0.45 }
                if bubbles[i].x > width - r { bubbles[i].x = width - r; bubbles[i].vx = -abs(bubbles[i].vx) * 0.45 }
                if bubbles[i].y < r { bubbles[i].y = r; bubbles[i].vy = abs(bubbles[i].vy) * 0.45 }
                if bubbles[i].y > height - r { bubbles[i].y = height - r; bubbles[i].vy = -abs(bubbles[i].vy) * 0.35 }
            }
        }
    }

    mutating func drag(id: String, x: Double, y: Double, vx: Double = 0, vy: Double = 0) {
        guard let i = bubbles.firstIndex(where: { $0.id == id }) else { return }
        bubbles[i].x = x; bubbles[i].y = y
        bubbles[i].vx = min(700, max(-700, vx)); bubbles[i].vy = min(700, max(-700, vy))
    }
}
