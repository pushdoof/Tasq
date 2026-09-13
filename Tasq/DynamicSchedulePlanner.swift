import Foundation

struct DynamicSchedulePlan {
    var events: [ChartEvent]
    var issue: String?
}

extension Chart {
    /// Pinned starts divide the window into independent gaps. Each gap reserves
    /// minimum durations first, then distributes whole spare minutes by weight.
    /// This keeps every generated start inside the window, including overnight.
    static func dynamicPlan(from configuration: DynamicScheduleConfiguration) -> DynamicSchedulePlan {
        func invalid(_ message: String) -> DynamicSchedulePlan { .init(events: [], issue: message) }
        func validTime(_ hour: Int, _ minute: Int) -> Bool { (1...12).contains(hour) && (0...59).contains(minute) }
        guard validTime(configuration.startHour, configuration.startMinute),
              validTime(configuration.endHour, configuration.endMinute) else {
            return invalid("Choose a valid start and end time.")
        }
        let tasks = configuration.dailyTasks.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !tasks.isEmpty else { return invalid("Add at least one task to your plan.") }
        let minimum = max(1, configuration.minimumTaskMinutes)
        let start = minutesFromMidnight(hour: configuration.startHour, minute: configuration.startMinute, isAM: configuration.startIsAM)
        var end = minutesFromMidnight(hour: configuration.endHour, minute: configuration.endMinute, isAM: configuration.endIsAM)
        guard start != end else { return invalid("Choose different start and end times for your routine.") }
        if end < start { end += 1440 }
        guard tasks.count <= (end - start) / minimum else {
            return invalid("These tasks need at least \(tasks.count * minimum) minutes. Widen the time window or lower the minimum task time.")
        }

        var pinned: [(task: DynamicScheduleTask, start: Int)] = []
        for task in tasks where task.hasFixedStartTime {
            guard let hour = task.fixedStartHour, let minute = task.fixedStartMinute, validTime(hour, minute) else {
                return invalid("Choose a valid pinned time for \(task.name).")
            }
            var time = minutesFromMidnight(hour: hour, minute: minute, isAM: task.fixedStartIsAM)
            if time < start { time += 1440 }
            guard time < end else { return invalid("\(task.name) is pinned outside your time window. Move its start or widen the window.") }
            pinned.append((task, time))
        }
        pinned.sort { $0.start < $1.start }
        struct Gap {
            var start: Int
            var end: Int
            var tasks: [DynamicScheduleTask]
        }
        var gaps: [Gap] = []
        if let first = pinned.first {
            if first.start > start { gaps.append(Gap(start: start, end: first.start, tasks: [])) }
            for index in pinned.indices {
                let stop = index + 1 < pinned.count ? pinned[index + 1].start : end
                guard stop - pinned[index].start >= minimum else {
                    return invalid("Pinned tasks overlap or leave too little time. Give \(pinned[index].task.name) at least \(minimum) minutes before the next pinned start or the end.")
                }
                gaps.append(Gap(start: pinned[index].start, end: stop, tasks: [pinned[index].task]))
            }
        } else {
            gaps = [Gap(start: start, end: end, tasks: [])]
        }

        let bias = configuration.importanceBias.isFinite ? min(2, max(0.5, configuration.importanceBias)) : 1
        let flexible = tasks.enumerated().filter { !$0.element.hasFixedStartTime }.sorted {
            let lhs = pow(Double(max(1, $0.element.importanceRank)), bias) / Double(max(1, $0.element.timeRank))
            let rhs = pow(Double(max(1, $1.element.importanceRank)), bias) / Double(max(1, $1.element.timeRank))
            return lhs == rhs ? $0.offset < $1.offset : lhs > rhs
        }
        for item in flexible {
            // Prefer the gap with the most unallocated space; ties stay chronological.
            let available = gaps.indices.filter { gaps[$0].end - gaps[$0].start - gaps[$0].tasks.count * minimum >= minimum }
            guard let index = available.sorted(by: {
                let a = gaps[$0].end - gaps[$0].start - gaps[$0].tasks.count * minimum
                let b = gaps[$1].end - gaps[$1].start - gaps[$1].tasks.count * minimum
                return a == b ? $0 < $1 : a > b
            }).first else {
                return invalid("There isn't a long enough gap for \(item.element.name). Move a pinned task or lower the minimum task time.")
            }
            gaps[index].tasks.append(item.element)
        }

        var events: [ChartEvent] = []
        for gap in gaps {
            if gap.tasks.isEmpty {
                let name = configuration.includeStartTimesInTitles ? "\(formattedClockTime(totalMinutes: gap.start)) - Free time" : "Free time"
                events.append(ChartEvent(name: name, durationMinutes: gap.end - gap.start))
                continue
            }
            let spare = gap.end - gap.start - gap.tasks.count * minimum
            let weights = gap.tasks.map { 1.0 / Double(max(1, $0.timeRank)) }
            let total = weights.reduce(0, +)
            let shares = weights.map { Double(spare) * $0 / total }
            var minutes = shares.map { minimum + Int($0.rounded(.down)) }
            let leftovers = gap.end - gap.start - minutes.reduce(0, +)
            let largestRemainders = shares.indices.sorted {
                let a = shares[$0] - shares[$0].rounded(.down)
                let b = shares[$1] - shares[$1].rounded(.down)
                return a == b ? $0 < $1 : a > b
            }
            for index in largestRemainders.prefix(leftovers) { minutes[index] += 1 }
            var cursor = gap.start
            for index in gap.tasks.indices {
                let task = gap.tasks[index]
                let title = configuration.includeStartTimesInTitles
                    ? "\(formattedClockTime(totalMinutes: cursor)) - \(task.name)" : task.name
                events.append(ChartEvent(id: task.id, name: title, durationMinutes: minutes[index]))
                cursor += minutes[index]
            }
        }
        return DynamicSchedulePlan(events: events, issue: nil)
    }
}
