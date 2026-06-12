import Foundation

struct ChartEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var durationMinutes: Int
    var isCompleted: Bool = false
    var isMissed: Bool = false
    var subtasks: [ChartEvent] = []

    var durationSeconds: Int {
        durationMinutes * 60
    }
}

enum ChartLayoutDirection: String, Codable, Equatable {
    case leftToRight
    case topToBottom
}

struct Chart: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var events: [ChartEvent]
    var alarmHour: Int? = nil
    var alarmMinute: Int? = nil
    var alarmIsAM: Bool = true
    var alarmEnabled: Bool = false
    var layoutDirection: ChartLayoutDirection = .leftToRight

    init(
        id: UUID = UUID(),
        name: String,
        events: [ChartEvent],
        alarmHour: Int? = nil,
        alarmMinute: Int? = nil,
        alarmIsAM: Bool = true,
        alarmEnabled: Bool = false,
        layoutDirection: ChartLayoutDirection = .leftToRight
    ) {
        self.id = id
        self.name = name
        self.events = events
        self.alarmHour = alarmHour
        self.alarmMinute = alarmMinute
        self.alarmIsAM = alarmIsAM
        self.alarmEnabled = alarmEnabled
        self.layoutDirection = layoutDirection
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case events
        case alarmHour
        case alarmMinute
        case alarmIsAM
        case alarmEnabled
        case layoutDirection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        events = try container.decode([ChartEvent].self, forKey: .events)
        alarmHour = try container.decodeIfPresent(Int.self, forKey: .alarmHour)
        alarmMinute = try container.decodeIfPresent(Int.self, forKey: .alarmMinute)
        alarmIsAM = try container.decodeIfPresent(Bool.self, forKey: .alarmIsAM) ?? true
        alarmEnabled = try container.decodeIfPresent(Bool.self, forKey: .alarmEnabled) ?? false
        layoutDirection = try container.decodeIfPresent(ChartLayoutDirection.self, forKey: .layoutDirection) ?? .leftToRight
    }
}

extension Chart {
    static let sample = Chart(
        name: "Morning Routine",
        events: [
            ChartEvent(name: "Wake up", durationMinutes: 10),
            ChartEvent(name: "Workout", durationMinutes: 30),
            ChartEvent(name: "Breakfast", durationMinutes: 20),
            ChartEvent(name: "Work Block 1", durationMinutes: 60)
        ]
    )

    static func blank() -> Chart {
        Chart(name: "Untitled Routine", events: [
            ChartEvent(name: "", durationMinutes: 10)
        ])
    }
}
