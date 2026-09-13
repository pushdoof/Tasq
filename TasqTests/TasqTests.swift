import Foundation
import Testing
@testable import Tasq

@MainActor
struct TasqTests {
    private func configuration(minutes: Int = 60, tasks: [DynamicScheduleTask]) -> DynamicScheduleConfiguration {
        var value = DynamicScheduleConfiguration.standard
        value.startHour = 7
        value.startMinute = 0
        value.endHour = 7 + minutes / 60
        value.endMinute = minutes % 60
        value.dailyTasks = tasks
        return value
    }

    @Test func unpinnedPlanUsesExactlyTheAvailableMinutes() {
        let tasks = (1...3).map { DynamicScheduleTask(name: "Task \($0)", timeRank: $0, importanceRank: $0) }
        let plan = Chart.dynamicPlan(from: configuration(minutes: 61, tasks: tasks))
        #expect(plan.issue == nil)
        #expect(plan.events.count == 3)
        #expect(plan.events.reduce(0) { $0 + $1.durationMinutes } == 61)
        #expect(plan.events.allSatisfy { $0.durationMinutes >= 5 })
        #expect(plan.events.first(where: { $0.id == tasks[0].id })!.durationMinutes > plan.events.first(where: { $0.id == tasks[2].id })!.durationMinutes)
    }

    @Test func pinnedTaskKeepsItsStartAndFlexibleTasksFitAroundIt() {
        let pin = DynamicScheduleTask(name: "Meeting", timeRank: 2, importanceRank: 5, fixedStartHour: 8, fixedStartMinute: 0)
        let tasks = [pin, DynamicScheduleTask(name: "Prepare", timeRank: 1, importanceRank: 5),
                     DynamicScheduleTask(name: "Read", timeRank: 3, importanceRank: 2)]
        let plan = Chart.dynamicPlan(from: configuration(minutes: 120, tasks: tasks))
        #expect(plan.issue == nil)
        let pinIndex = plan.events.firstIndex { $0.id == pin.id }!
        #expect(plan.events[..<pinIndex].reduce(0) { $0 + $1.durationMinutes } == 60)
        #expect(plan.events[pinIndex].name == "8:00 AM - Meeting")
        #expect(plan.events.reduce(0) { $0 + $1.durationMinutes } == 120)
    }

    @Test func duplicatePinnedTimesAreRejected() {
        let tasks = ["Meeting", "Breakfast"].map {
            DynamicScheduleTask(name: $0, timeRank: 1, importanceRank: 1, fixedStartHour: 7, fixedStartMinute: 30)
        }
        let plan = Chart.dynamicPlan(from: configuration(tasks: tasks))
        #expect(plan.issue != nil)
        #expect(plan.events.isEmpty)
    }

    @Test func impossibleMinimumDurationsAreRejected() {
        let tasks = (1...4).map { DynamicScheduleTask(name: "Task \($0)", timeRank: 1, importanceRank: 1) }
        let plan = Chart.dynamicPlan(from: configuration(minutes: 15, tasks: tasks))
        #expect(plan.issue != nil)
        #expect(plan.events.isEmpty)
    }

    @Test func overnightPinnedTimesStayInChronologicalOrder() {
        let task = DynamicScheduleTask(name: "Read", timeRank: 1, importanceRank: 1,
                                       fixedStartHour: 1, fixedStartMinute: 0, fixedStartIsAM: true)
        var value = configuration(tasks: [task])
        value.startHour = 11
        value.startIsAM = false
        value.endHour = 2
        value.endIsAM = true
        let plan = Chart.dynamicPlan(from: value)
        #expect(plan.issue == nil)
        #expect(plan.events.first?.name == "11:00 PM - Free time")
        #expect(plan.events.last?.name == "1:00 AM - Read")
        #expect(plan.events.reduce(0) { $0 + $1.durationMinutes } == 180)
    }

    @Test func outOfWindowPinsAndEmptyPlansAreRejected() {
        let task = DynamicScheduleTask(name: "Outside", timeRank: 1, importanceRank: 1,
                                       fixedStartHour: 9, fixedStartMinute: 0)
        #expect(Chart.dynamicPlan(from: configuration(tasks: [task])).issue != nil)
        #expect(Chart.dynamicPlan(from: configuration(tasks: [])).issue != nil)
        var sameStartAndEnd = configuration(tasks: [task])
        sameStartAndEnd.endHour = sameStartAndEnd.startHour
        #expect(Chart.dynamicPlan(from: sameStartAndEnd).issue != nil)
    }

    @Test func generatedPlansStayBoundedAcrossManyWindowSizes() {
        for minutes in 5...150 {
            for count in 1...min(6, minutes / 5) {
                let tasks = (1...count).map { DynamicScheduleTask(name: "Task \($0)", timeRank: $0, importanceRank: 6 - $0) }
                let plan = Chart.dynamicPlan(from: configuration(minutes: minutes, tasks: tasks))
                #expect(plan.issue == nil)
                #expect(plan.events.reduce(0) { $0 + $1.durationMinutes } == minutes)
                #expect(plan.events.allSatisfy { $0.durationMinutes >= 5 })
            }
        }
    }

    @Test func clockCatchesUpAfterAppSuspension() {
        let events = [ChartEvent(name: "A", durationMinutes: 1), ChartEvent(name: "B", durationMinutes: 2), ChartEvent(name: "C", durationMinutes: 3)]
        #expect(RoutineClock.position(events: events, elapsed: 125) == RoutinePosition(index: 1, secondsRemaining: 55, elapsedBeforeTask: 60))
        #expect(RoutineClock.position(events: events, elapsed: 180) == RoutinePosition(index: 2, secondsRemaining: 180, elapsedBeforeTask: 180))
        #expect(RoutineClock.position(events: events, elapsed: 360) == nil)
        #expect(RoutineClock.position(events: events, elapsed: 9999) == nil)
    }

    @Test func clockHandlesEarlyStartAndEmptyRoutine() {
        let event = ChartEvent(name: "A", durationMinutes: 1)
        #expect(RoutineClock.position(events: [event], elapsed: -10)?.secondsRemaining == 60)
        #expect(RoutineClock.position(events: [], elapsed: 0) == nil)
    }

    @Test func pausedSnapshotRoundTripsWithoutLosingRemainingTime() throws {
        let snapshot = ActiveRoutineSnapshot(chartID: UUID(), currentEventIndex: 2, secondsRemaining: 47,
                                             routineStartDate: Date(timeIntervalSince1970: 1234), isPaused: true)
        let restored = try JSONDecoder().decode(ActiveRoutineSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(restored.isPaused)
        #expect(restored.secondsRemaining == 47)
        #expect(restored.currentEventIndex == 2)
        #expect(restored.routineStartDate == snapshot.routineStartDate)
        #expect(ActiveRoutineSnapshot.key(for: restored.chartID) != ActiveRoutineSnapshot.key(for: UUID()))
    }

    @Test func olderRoutineDataStillDecodes() throws {
        let json = #"{"name":"Morning","events":[{"id":"DA883A88-47CC-4565-A935-A667068D4472","name":"Breakfast","durationMinutes":15,"isCompleted":false,"isMissed":false,"subtasks":[]}]}"#
        let chart = try JSONDecoder().decode(Chart.self, from: Data(json.utf8))
        #expect(chart.scheduleType == .diagram)
        #expect(chart.alarmEnabled == false)
        #expect(chart.events.first?.name == "Breakfast")
    }
}
