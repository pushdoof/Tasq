import Foundation

struct ActiveRoutineSnapshot: Codable {
    var chartID: UUID
    var currentEventIndex: Int
    var secondsRemaining: Int
    var routineStartDate: Date?
    var isPaused: Bool

    func hasFinished(events: [ChartEvent], now: Date = .now) -> Bool {
        guard !isPaused, let routineStartDate else { return false }
        return RoutineClock.position(events: events, elapsed: Int(now.timeIntervalSince(routineStartDate))) == nil
    }

    static func key(for chartID: UUID) -> String { "activeRoutineSnapshot-\(chartID.uuidString)" }

    static func load(chartID: UUID) -> ActiveRoutineSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key(for: chartID)),
              let snapshot = try? JSONDecoder().decode(Self.self, from: data),
              snapshot.chartID == chartID else { return nil }
        return snapshot
    }
}

struct RoutinePosition: Equatable {
    let index: Int
    let secondsRemaining: Int
    let elapsedBeforeTask: Int
}

enum RoutineClock {
    /// Reconstruct progress from elapsed wall-clock time, rather than counting
    /// timer ticks that iOS can suspend while the app is in the background.
    static func position(events: [ChartEvent], elapsed: Int) -> RoutinePosition? {
        let elapsed = max(0, elapsed)
        var before = 0
        for index in events.indices {
            let end = before + max(0, events[index].durationSeconds)
            if elapsed < end {
                return RoutinePosition(index: index, secondsRemaining: end - elapsed, elapsedBeforeTask: before)
            }
            before = end
        }
        return nil
    }
}
