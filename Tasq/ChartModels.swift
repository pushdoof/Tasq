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

enum ChartLayoutDirection: String, Codable, Equatable, Hashable {
    case leftToRight
    case topToBottom
}

enum ChartScheduleType: String, Codable, CaseIterable, Identifiable, Equatable {
    case diagram
    case dynamic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diagram: return "Diagram"
        case .dynamic: return "Dynamic"
        }
    }
}

struct DynamicScheduleTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var timeRank: Int
    var importanceRank: Int
    var fixedStartHour: Int? = nil
    var fixedStartMinute: Int? = nil
    var fixedStartIsAM: Bool = true

    var hasFixedStartTime: Bool {
        fixedStartHour != nil && fixedStartMinute != nil
    }
}

struct DynamicScheduleConfiguration: Codable, Equatable {
    var dailyTasks: [DynamicScheduleTask]
    var startHour: Int
    var startMinute: Int
    var startIsAM: Bool
    var endHour: Int
    var endMinute: Int
    var endIsAM: Bool
    var minimumTaskMinutes: Int
    var importanceBias: Double
    var includeStartTimesInTitles: Bool
    var setupCompleted: Bool

    static let standard = DynamicScheduleConfiguration(
        dailyTasks: [
            DynamicScheduleTask(name: "Get ready", timeRank: 2, importanceRank: 4),
            DynamicScheduleTask(name: "Breakfast", timeRank: 3, importanceRank: 3),
            DynamicScheduleTask(name: "Focus work", timeRank: 5, importanceRank: 5),
            DynamicScheduleTask(name: "Clean up", timeRank: 1, importanceRank: 2)
        ],
        startHour: 7,
        startMinute: 0,
        startIsAM: true,
        endHour: 9,
        endMinute: 0,
        endIsAM: true,
        minimumTaskMinutes: 5,
        importanceBias: 1.0,
        includeStartTimesInTitles: true,
        setupCompleted: false
    )

    enum CodingKeys: String, CodingKey {
        case dailyTasks
        case startHour
        case startMinute
        case startIsAM
        case endHour
        case endMinute
        case endIsAM
        case minimumTaskMinutes
        case importanceBias
        case includeStartTimesInTitles
        case setupCompleted
    }

    init(
        dailyTasks: [DynamicScheduleTask],
        startHour: Int,
        startMinute: Int,
        startIsAM: Bool,
        endHour: Int,
        endMinute: Int,
        endIsAM: Bool,
        minimumTaskMinutes: Int,
        importanceBias: Double,
        includeStartTimesInTitles: Bool,
        setupCompleted: Bool = false
    ) {
        self.dailyTasks = dailyTasks
        self.startHour = startHour
        self.startMinute = startMinute
        self.startIsAM = startIsAM
        self.endHour = endHour
        self.endMinute = endMinute
        self.endIsAM = endIsAM
        self.minimumTaskMinutes = minimumTaskMinutes
        self.importanceBias = importanceBias
        self.includeStartTimesInTitles = includeStartTimesInTitles
        self.setupCompleted = setupCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dailyTasks = try container.decode([DynamicScheduleTask].self, forKey: .dailyTasks)
        startHour = try container.decode(Int.self, forKey: .startHour)
        startMinute = try container.decode(Int.self, forKey: .startMinute)
        startIsAM = try container.decode(Bool.self, forKey: .startIsAM)
        endHour = try container.decode(Int.self, forKey: .endHour)
        endMinute = try container.decode(Int.self, forKey: .endMinute)
        endIsAM = try container.decode(Bool.self, forKey: .endIsAM)
        minimumTaskMinutes = try container.decodeIfPresent(Int.self, forKey: .minimumTaskMinutes) ?? 5
        importanceBias = try container.decodeIfPresent(Double.self, forKey: .importanceBias) ?? 1.0
        includeStartTimesInTitles = try container.decodeIfPresent(Bool.self, forKey: .includeStartTimesInTitles) ?? true
        setupCompleted = try container.decodeIfPresent(Bool.self, forKey: .setupCompleted) ?? true
    }
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
    var scheduleType: ChartScheduleType = .diagram
    var dynamicConfiguration: DynamicScheduleConfiguration? = nil

    init(
        id: UUID = UUID(),
        name: String,
        events: [ChartEvent],
        alarmHour: Int? = nil,
        alarmMinute: Int? = nil,
        alarmIsAM: Bool = true,
        alarmEnabled: Bool = false,
        layoutDirection: ChartLayoutDirection = .leftToRight,
        scheduleType: ChartScheduleType = .diagram,
        dynamicConfiguration: DynamicScheduleConfiguration? = nil
    ) {
        self.id = id
        self.name = name
        self.events = events
        self.alarmHour = alarmHour
        self.alarmMinute = alarmMinute
        self.alarmIsAM = alarmIsAM
        self.alarmEnabled = alarmEnabled
        self.layoutDirection = layoutDirection
        self.scheduleType = scheduleType
        self.dynamicConfiguration = dynamicConfiguration
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
        case scheduleType
        case dynamicConfiguration
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
        scheduleType = try container.decodeIfPresent(ChartScheduleType.self, forKey: .scheduleType) ?? .diagram
        dynamicConfiguration = try container.decodeIfPresent(DynamicScheduleConfiguration.self, forKey: .dynamicConfiguration)
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

    static func blank(type: ChartScheduleType = .diagram) -> Chart {
        switch type {
        case .diagram:
            return Chart(name: "Untitled Routine", events: [
                ChartEvent(name: "", durationMinutes: 10)
            ])
        case .dynamic:
            var chart = Chart(
                name: "Dynamic Routine",
                events: [],
                layoutDirection: .topToBottom,
                scheduleType: .dynamic,
                dynamicConfiguration: .standard
            )
            chart.regenerateDynamicEvents()
            return chart
        }
    }

    mutating func ensureDynamicConfiguration() {
        guard scheduleType == .dynamic else { return }
        if dynamicConfiguration == nil {
            dynamicConfiguration = .standard
        }
        if events.isEmpty {
            regenerateDynamicEvents()
        }
    }

    mutating func regenerateDynamicEvents() {
        guard scheduleType == .dynamic, let configuration = dynamicConfiguration else { return }
        events = Self.generatedEvents(from: configuration)
    }

    static func generatedEvents(from configuration: DynamicScheduleConfiguration) -> [ChartEvent] {
        let tasks = configuration.dailyTasks.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !tasks.isEmpty else {
            return [ChartEvent(name: "Add daily tasks", durationMinutes: configuration.minimumTaskMinutes)]
        }

        let slotMinutes = max(configuration.minimumTaskMinutes * tasks.count, minutesBetweenStartAndEnd(in: configuration))
        let minimumTotal = configuration.minimumTaskMinutes * tasks.count
        let flexibleMinutes = max(0, slotMinutes - minimumTotal)
        let timeWeightTotal = tasks.reduce(0.0) { total, task in
            total + (1.0 / Double(max(1, task.timeRank)))
        }

        var scheduledTasks = tasks.map { task -> ScheduledDynamicTask in
            let zipfShare = (1.0 / Double(max(1, task.timeRank))) / max(timeWeightTotal, 0.001)
            let duration = configuration.minimumTaskMinutes + Int((Double(flexibleMinutes) * zipfShare).rounded())
            let priority = pow(Double(max(1, task.importanceRank)), configuration.importanceBias) / Double(max(1, task.timeRank))
            return ScheduledDynamicTask(task: task, durationMinutes: max(configuration.minimumTaskMinutes, duration), priority: priority)
        }

        scheduledTasks.sort { first, second in
            if first.task.hasFixedStartTime != second.task.hasFixedStartTime {
                return first.task.hasFixedStartTime
            }
            if first.fixedStartMinutes != second.fixedStartMinutes {
                return (first.fixedStartMinutes ?? Int.max) < (second.fixedStartMinutes ?? Int.max)
            }
            return first.priority > second.priority
        }

        var cursor = minutesFromMidnight(hour: configuration.startHour, minute: configuration.startMinute, isAM: configuration.startIsAM)
        return scheduledTasks.map { scheduled in
            if let fixedStartMinutes = scheduled.fixedStartMinutes {
                cursor = fixedStartMinutes
            }
            let title = configuration.includeStartTimesInTitles
                ? "\(formattedClockTime(totalMinutes: cursor)) - \(scheduled.task.name)"
                : scheduled.task.name
            cursor += scheduled.durationMinutes
            return ChartEvent(name: title, durationMinutes: scheduled.durationMinutes)
        }
    }

    private struct ScheduledDynamicTask {
        var task: DynamicScheduleTask
        var durationMinutes: Int
        var priority: Double

        var fixedStartMinutes: Int? {
            guard let hour = task.fixedStartHour, let minute = task.fixedStartMinute else { return nil }
            return Chart.minutesFromMidnight(hour: hour, minute: minute, isAM: task.fixedStartIsAM)
        }
    }

    private static func minutesBetweenStartAndEnd(in configuration: DynamicScheduleConfiguration) -> Int {
        let start = minutesFromMidnight(hour: configuration.startHour, minute: configuration.startMinute, isAM: configuration.startIsAM)
        let end = minutesFromMidnight(hour: configuration.endHour, minute: configuration.endMinute, isAM: configuration.endIsAM)
        if end > start {
            return end - start
        }
        return (24 * 60 - start) + end
    }

    static func minutesFromMidnight(hour: Int, minute: Int, isAM: Bool) -> Int {
        var calendarHour = hour
        if !isAM && calendarHour != 12 {
            calendarHour += 12
        }
        if isAM && calendarHour == 12 {
            calendarHour = 0
        }
        return calendarHour * 60 + minute
    }

    static func formattedClockTime(totalMinutes: Int) -> String {
        let normalizedMinutes = ((totalMinutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        let hour24 = normalizedMinutes / 60
        let minute = normalizedMinutes % 60
        let isAM = hour24 < 12
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minute, isAM ? "AM" : "PM")
    }
}
