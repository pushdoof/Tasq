//
//  ChartEditorView.swift
//  Tasq
//

import SwiftUI
import UserNotifications
internal import Combine

struct ActiveRoutineSnapshot: Codable {
    var chartID: UUID
    var currentEventIndex: Int
    var secondsRemaining: Int
    var routineStartDate: Date?
    var isPaused: Bool
} // Miller kids built different

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    @Published var shouldStartTimer = false

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == "alarm" {
            DispatchQueue.main.async {
                self.shouldStartTimer = true
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

struct ChartEditorView: View {
    @Binding var chart: Chart
    let defaultZoom: Double
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var progressStore: UserProgressStore
    @StateObject private var notificationDelegate = NotificationDelegate()
    @State private var zoomScale: CGFloat = 1.3
    @State private var isEditingAll = false
    @State private var isEditingTitle = false
    @State private var showSideMenu = false
    @State private var optionSelected = false
    @State private var showAlarmPicker = false
    @State private var showDynamicSetupWizard = false
    @State private var alarmHour = 7
    @State private var alarmMinute = 0
    @State private var alarmIsAM = true
    @State private var showConfetti = false
    @AppStorage("calmCelebrations") private var calmCelebrations = false
    @AppStorage("boldText") private var boldText = false

    // Timer state
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var currentEventIndex = 0
    @State private var secondsRemaining = 0
    @State private var timer: Timer? = nil
    @State private var taskStartDate: Date? = nil
    @State private var routineStartDate: Date? = nil

    let haptic = UIImpactFeedbackGenerator(style: .medium)
    let successHaptic = UINotificationFeedbackGenerator()

    var currentEvent: ChartEvent? {
        guard currentEventIndex < chart.events.count else { return nil }
        return chart.events[currentEventIndex]
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    private var routineNotificationIdentifiers: [String] {
        chart.events.indices.map { "task-\($0)" } + ["routine-complete", "routine-complete-now"]
    }

    private var activeRoutineSnapshotKey: String {
        "activeRoutineSnapshot-\(chart.id.uuidString)"
    }

    func scheduleNotifications(from startIndex: Int = 0, currentTaskRemaining: Int? = nil) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: routineNotificationIdentifiers)
        var delay: TimeInterval = TimeInterval(currentTaskRemaining ?? 0)
        let firstNotificationIndex = startIndex + 1

        if currentTaskRemaining == nil, chart.events.indices.contains(startIndex) {
            scheduleTaskNotification(for: startIndex, after: 1, isFirstVisibleTask: true)
            delay += TimeInterval(chart.events[startIndex].durationSeconds)
        }

        for index in chart.events.indices where index >= firstNotificationIndex {
            let event = chart.events[index]
            scheduleTaskNotification(for: index, after: max(1, delay), isFirstVisibleTask: index == startIndex)
            delay += TimeInterval(event.durationSeconds)
        }

        scheduleRoutineCompleteNotification(after: max(1, delay), identifier: "routine-complete")
    }

    func scheduleTaskNotification(for index: Int, after delay: TimeInterval, isFirstVisibleTask: Bool) {
        guard chart.events.indices.contains(index) else { return }
        let event = chart.events[index]
        let content = UNMutableNotificationContent()
        content.title = "Tasq"
        content.body = isFirstVisibleTask
            ? "Starting: \(event.name.isEmpty ? "Task \(index + 1)" : event.name)"
            : "Time for: \(event.name.isEmpty ? "Task \(index + 1)" : event.name)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_loop.caf"))
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: "task-\(index)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleRoutineCompleteNotification(after delay: TimeInterval = 1, identifier: String = "routine-complete-now") {
        let content = UNMutableNotificationContent()
        content.title = "Tasq"
        content.body = "All tasks complete in \(chart.name)."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleAlarmNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["alarm"])
        guard chart.alarmEnabled,
              let hour = chart.alarmHour,
              let minute = chart.alarmMinute else { return }
        var h = hour
        if !chart.alarmIsAM && h != 12 { h += 12 }
        if chart.alarmIsAM && h == 12 { h = 0 }
        var components = DateComponents()
        components.hour = h
        components.minute = minute
        let content = UNMutableNotificationContent()
        content.title = "Tasq"
        content.body = "Time to start \(chart.name)!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_loop.caf"))
        content.interruptionLevel = .timeSensitive
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "alarm", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleTimer() {
        timer?.invalidate()
        guard !isPaused else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                synchronizeTimerWithCurrentDate(sendCompletionNotification: true)
            }
        }
    }

    func startTimer() {
        for i in chart.events.indices {
            chart.events[i].isCompleted = false
            for j in chart.events[i].subtasks.indices {
                chart.events[i].subtasks[j].isCompleted = false
            }
        }
        currentEventIndex = 0
        let startDate = Date()
        routineStartDate = startDate
        taskStartDate = startDate
        secondsRemaining = (chart.events.first?.durationMinutes ?? 1) * 60
        isRunning = true
        isPaused = false
        haptic.impactOccurred()
        scheduleNotifications()
        saveActiveRoutineSnapshot()
        scheduleTimer()
    }

    func stopTimer(removeRoutineNotifications: Bool = true) {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        currentEventIndex = 0
        secondsRemaining = 0
        taskStartDate = nil
        routineStartDate = nil
        if removeRoutineNotifications {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: routineNotificationIdentifiers)
        }
        clearActiveRoutineSnapshot()
        scheduleAlarmNotification()
    }

    func pauseTimer() {
        guard isRunning, !isPaused else { return }
        synchronizeTimerWithCurrentDate()
        timer?.invalidate()
        timer = nil
        isPaused = true
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: routineNotificationIdentifiers)
        saveActiveRoutineSnapshot()
    }

    func resumeTimer() {
        guard isRunning, isPaused, chart.events.indices.contains(currentEventIndex) else { return }
        let elapsedInCurrentTask = chart.events[currentEventIndex].durationSeconds - secondsRemaining
        let totalElapsed = durationBeforeEvent(at: currentEventIndex) + max(0, elapsedInCurrentTask)
        let startDate = Date().addingTimeInterval(-TimeInterval(totalElapsed))
        routineStartDate = startDate
        taskStartDate = startDate.addingTimeInterval(TimeInterval(durationBeforeEvent(at: currentEventIndex)))
        isPaused = false
        scheduleNotifications(from: currentEventIndex, currentTaskRemaining: secondsRemaining)
        saveActiveRoutineSnapshot()
        scheduleTimer()
    }

    func advanceToNext() {
        if currentEventIndex < chart.events.count {
            chart.events[currentEventIndex].isCompleted = true
        }
        let nextIndex = currentEventIndex + 1
        if nextIndex < chart.events.count {
            currentEventIndex = nextIndex
            let startDate = Date()
            taskStartDate = startDate
            routineStartDate = startDate.addingTimeInterval(-TimeInterval(durationBeforeEvent(at: nextIndex)))
            secondsRemaining = chart.events[nextIndex].durationMinutes * 60
            haptic.impactOccurred()
            scheduleNotifications(from: nextIndex)
            saveActiveRoutineSnapshot()
            scheduleTimer()
        } else {
            completeRoutine(sendNotification: true)
        }
    }

    func synchronizeTimerWithCurrentDate(sendCompletionNotification: Bool = false) {
        guard isRunning, !isPaused, let routineStartDate else { return }

        let elapsed = max(0, Int(Date().timeIntervalSince(routineStartDate)))
        var elapsedBeforeEvent = 0

        for index in chart.events.indices {
            let eventEnd = elapsedBeforeEvent + chart.events[index].durationSeconds

            if elapsed >= eventEnd {
                chart.events[index].isCompleted = true
                elapsedBeforeEvent = eventEnd
                continue
            }

            if currentEventIndex != index {
                haptic.impactOccurred()
            }
            currentEventIndex = index
            taskStartDate = routineStartDate.addingTimeInterval(TimeInterval(elapsedBeforeEvent))
            secondsRemaining = max(0, eventEnd - elapsed)
            saveActiveRoutineSnapshot()
            return
        }

        completeRoutine(sendNotification: sendCompletionNotification)
    }

    func completeRoutine(sendNotification: Bool) {
        for index in chart.events.indices {
            chart.events[index].isCompleted = true
        }
        successHaptic.notificationOccurred(.success)
        if !calmCelebrations {
            withAnimation {
                showConfetti = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation {
                    showConfetti = false
                }
            }
        }
        stopTimer()
        if sendNotification {
            scheduleRoutineCompleteNotification()
        }
    }

    func durationBeforeEvent(at index: Int) -> Int {
        chart.events.indices
            .filter { $0 < index }
            .reduce(0) { $0 + chart.events[$1].durationSeconds }
    }

    func saveActiveRoutineSnapshot() {
        guard isRunning else {
            clearActiveRoutineSnapshot()
            return
        }

        let snapshot = ActiveRoutineSnapshot(
            chartID: chart.id,
            currentEventIndex: currentEventIndex,
            secondsRemaining: secondsRemaining,
            routineStartDate: routineStartDate,
            isPaused: isPaused
        )
        if let encoded = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(encoded, forKey: activeRoutineSnapshotKey)
        }
    }

    func restoreActiveRoutineSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: activeRoutineSnapshotKey),
              let snapshot = try? JSONDecoder().decode(ActiveRoutineSnapshot.self, from: data),
              snapshot.chartID == chart.id,
              chart.events.indices.contains(snapshot.currentEventIndex) else { return }

        isRunning = true
        isPaused = snapshot.isPaused
        currentEventIndex = snapshot.currentEventIndex
        secondsRemaining = snapshot.secondsRemaining
        routineStartDate = snapshot.routineStartDate
        if let routineStartDate {
            taskStartDate = routineStartDate.addingTimeInterval(TimeInterval(durationBeforeEvent(at: currentEventIndex)))
        }

        if isPaused {
            timer?.invalidate()
            timer = nil
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: routineNotificationIdentifiers)
        } else {
            synchronizeTimerWithCurrentDate()
            if isRunning {
                scheduleTimer()
            }
        }
    }

    func clearActiveRoutineSnapshot() {
        UserDefaults.standard.removeObject(forKey: activeRoutineSnapshotKey)
    }

    func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    func formattedAlarm() -> String {
        guard let h = chart.alarmHour, let m = chart.alarmMinute else { return "Not set" }
        return String(format: "%d:%02d %@", h, m, chart.alarmIsAM ? "AM" : "PM")
    }

    func finishTimeText(for index: Int) -> String? {
        guard chart.alarmEnabled,
              let hour = chart.alarmHour,
              let minute = chart.alarmMinute,
              chart.events.indices.contains(index) else { return nil }

        var calendarHour = hour
        if !chart.alarmIsAM && calendarHour != 12 {
            calendarHour += 12
        }
        if chart.alarmIsAM && calendarHour == 12 {
            calendarHour = 0
        }

        var startComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        startComponents.hour = calendarHour
        startComponents.minute = minute

        guard let startDate = Calendar.current.date(from: startComponents) else { return nil }
        let durationThroughEvent = chart.events.indices
            .filter { $0 <= index }
            .reduce(0) { $0 + chart.events[$1].durationSeconds }
        let finishDate = startDate.addingTimeInterval(TimeInterval(durationThroughEvent))
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "done \(formatter.string(from: finishDate))"
    }

    @ViewBuilder
    private var chartFlowContent: some View {
        if chart.layoutDirection == .topToBottom {
            VStack(alignment: .center, spacing: 0) {
                if chart.alarmEnabled {
                    AlarmBlockView(chart: $chart, layoutDirection: chart.layoutDirection)
                    ConnectorView(direction: .topToBottom)
                }

                ForEach(Array(chart.events.enumerated()), id: \.element.id) { index, _ in
                    flowNode(at: index)

                    if index < chart.events.count - 1 {
                        ConnectorView(direction: .topToBottom)
                    }
                }
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                if chart.alarmEnabled {
                    AlarmBlockView(chart: $chart, layoutDirection: chart.layoutDirection)
                    ConnectorView(direction: .leftToRight)
                        .padding(.top, 30)
                }

                ForEach(Array(chart.events.enumerated()), id: \.element.id) { index, _ in
                    flowNode(at: index)

                    if index < chart.events.count - 1 {
                        ConnectorView(direction: .leftToRight)
                            .padding(.top, 30)
                    }
                }
            }
        }
    }

    private var flowHorizontalPadding: CGFloat {
        let basePadding: CGFloat = chart.layoutDirection == .topToBottom ? 72 : 180
        return basePadding * zoomScale * zoomScale * zoomScale
    }

    private var flowVerticalPadding: CGFloat {
        let basePadding: CGFloat = chart.layoutDirection == .topToBottom ? 80 : 40
        return basePadding * zoomScale * zoomScale * zoomScale
    }

    @ViewBuilder
    private func flowNode(at index: Int) -> some View {
        FlowNodeView(
            event: $chart.events[index],
            isEditingAll: isEditingAll,
            canDelete: chart.events.count > 1,
            isRunning: isRunning,
            isCurrentTask: isRunning && index == currentEventIndex,
            finishTimeText: finishTimeText(for: index),
            onAdd: {
                let newEvent = ChartEvent(name: "", durationMinutes: 10)
                chart.events.insert(newEvent, at: index + 1)
                haptic.impactOccurred()
            },
            onDelete: {
                chart.events.remove(at: index)
                haptic.impactOccurred()
            },
            onComplete: {
                advanceToNext()
            },
            layoutDirection: chart.layoutDirection
        )
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        withAnimation {
                            showSideMenu.toggle()
                        }
                        haptic.impactOccurred()
                    } label: {
                        TasqIcon("line.3.horizontal", size: 22)
                            .foregroundStyle(Color.chartflowText)
                    }
                    .padding(.leading, 20)
                    Spacer()
                }
                .padding(.top, 12)

                HStack(spacing: 8) {
                    if isEditingTitle {
                        TextField("Chart Name", text: $chart.name, onCommit: {
                            if chart.name.trimmingCharacters(in: .whitespaces).isEmpty {
                                chart.name = "Untitled Routine"
                            }
                            isEditingTitle = false
                        })
                        .font(.custom("ChartflowHand-Regular", size: 34))
                        .fontWeight(boldText ? .black : .bold)
                        .foregroundStyle(Color.chartflowText)
                        .textFieldStyle(.plain)
                    } else {
                        Text(chart.name)
                            .font(.custom("ChartflowHand-Regular", size: 34))
                            .fontWeight(boldText ? .black : .bold)
                            .foregroundStyle(Color.chartflowText)
                    }

                    Button {
                        if isEditingTitle {
                            if chart.name.trimmingCharacters(in: .whitespaces).isEmpty {
                                chart.name = "Untitled Routine"
                            }
                        }
                        isEditingTitle.toggle()
                        haptic.impactOccurred()
                    } label: {
                        TasqIcon(isEditingTitle ? "checkmark.circle" : "pencil.circle", size: 20)
                            .foregroundStyle(Color.chartflowSecondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)

                if chart.scheduleType == .dynamic {
                    Button {
                        showDynamicSetupWizard = true
                        haptic.impactOccurred()
                    } label: {
                        Label {
                            Text("Dynamic Setup")
                        } icon: {
                            TasqIcon("wand.and.stars", size: 17)
                        }
                            .font(.custom("ChartflowHand-Regular", size: 17))
                            .fontWeight(boldText ? .bold : .regular)
                            .foregroundStyle(isRunning ? Color.gray.opacity(0.5) : Color.chartflowText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .chartflowBox(cornerRadius: 12, wobble: 1.5, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                GeometryReader { geometry in
                    ScrollView([.vertical, .horizontal]) {
                        chartFlowContent
                            .padding(.horizontal, flowHorizontalPadding)
                            .padding(.vertical, flowVerticalPadding)
                            .scaleEffect(zoomScale)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PolkaDotBackground())
            }
            .background(Color.chartflowBackground.ignoresSafeArea())
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack {
                    Spacer()
                    Text("🎉 Routine Complete!")
                        .font(.custom("ChartflowHand-Regular", size: 28))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.chartflowText)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.chartflowSurface)
                                .shadow(color: .black.opacity(0.15), radius: 10)
                        )
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Bottom bar
            VStack(spacing: 0) {
                if isRunning {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentEvent?.name.isEmpty == false ? currentEvent!.name : "Task \(currentEventIndex + 1)")
                                .font(.custom("ChartflowHand-Regular", size: 18))
                                .fontWeight(boldText ? .bold : .regular)
                                .foregroundStyle(Color.chartflowText)
                                .lineLimit(1)
                            Text("Task \(currentEventIndex + 1) of \(chart.events.count)")
                                .font(.custom("ChartflowHand-Regular", size: 13))
                                .fontWeight(boldText ? .semibold : .regular)
                                .foregroundStyle(Color.chartflowSecondaryText)
                            if isPaused {
                                Text("Paused")
                                    .font(.custom("ChartflowHand-Regular", size: 13))
                                    .foregroundStyle(Color.chartflowSecondaryText)
                            }
                        }
                        Spacer()
                        Text(formattedTime(secondsRemaining))
                            .font(.custom("ChartflowHand-Regular", size: 32))
                            .fontWeight(boldText ? .black : .regular)
                            .foregroundStyle(Color.chartflowText)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.chartflowSurface)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Zoom controls
                HStack(spacing: 20) {
                    Button {
                        withAnimation { zoomScale = max(0.5, zoomScale - 0.1) }
                        haptic.impactOccurred()
                    } label: {
                        TasqIcon("minus.magnifyingglass", size: 20)
                    }

                    Text("\(Int(zoomScale * 100))%")
                        .font(.custom("ChartflowHand-Regular", size: 16))
                        .frame(width: 50)

                    Button {
                        withAnimation { zoomScale = min(2.0, zoomScale + 0.1) }
                        haptic.impactOccurred()
                    } label: {
                        TasqIcon("plus.magnifyingglass", size: 20)
                    }
                }
                .padding(.top, 12)
                .foregroundStyle(Color.chartflowText)

                HStack {
                    Button {
                        if !isRunning {
                            isEditingAll.toggle()
                            haptic.impactOccurred()
                        }
                    } label: {
                        TasqIcon(isEditingAll ? "checkmark.circle.fill" : "pencil.circle.fill", size: 44)
                            .foregroundStyle(isRunning ? Color.gray.opacity(0.4) : (isEditingAll ? Color.blue : Color.chartflowText))
                            .background(Color.chartflowSurface)
                            .clipShape(Circle())
                    }
                    .disabled(isRunning)
                    .padding(.leading, 20)

                    Spacer()

                    if isRunning {
                        Button {
                            withAnimation {
                                if isPaused {
                                    resumeTimer()
                                } else {
                                    pauseTimer()
                                }
                            }
                            haptic.impactOccurred()
                        } label: {
                            TasqIcon(isPaused ? "playpause.circle.fill" : "pause.circle.fill", size: 44)
                                .foregroundStyle(Color.chartflowText)
                                .background(Color.chartflowSurface)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(isPaused ? "Resume Routine" : "Pause Routine")

                        Spacer()
                    }

                    Button {
                        withAnimation {
                            if isRunning {
                                stopTimer()
                            } else {
                                isEditingAll = false
                                startTimer()
                            }
                        }
                        haptic.impactOccurred()
                    } label: {
                        TasqIcon(isRunning ? "stop.circle.fill" : "play.circle.fill", size: 44)
                            .foregroundStyle(Color.chartflowText)
                            .background(Color.chartflowSurface)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 16)
                .padding(.top, 8)
            }
            .background(Color.chartflowSurface)
            .frame(maxWidth: .infinity)

            // Dimmed background when side menu is open
            if showSideMenu {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showSideMenu = false }
                        haptic.impactOccurred()
                    }
                    .animation(.easeInOut(duration: 0.25), value: showSideMenu)
            }

            // Side menu
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 80)

                    Text("Home")
                        .font(.custom("ChartflowHand-Regular", size: 24))
                        .foregroundStyle(Color.chartflowText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(optionSelected ? Color.gray.opacity(0.3) : Color.clear)
                        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressing in
                            optionSelected = isPressing
                        }, perform: {
                            haptic.impactOccurred()
                            dismiss()
                        })

                    Divider()
                        .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Layout")
                            .font(.custom("ChartflowHand-Regular", size: 24))
                            .foregroundStyle(Color.chartflowText)

                        Picker("Layout", selection: $chart.layoutDirection) {
                            Text("Left to Right").tag(ChartLayoutDirection.leftToRight)
                            Text("Top to Bottom").tag(ChartLayoutDirection.topToBottom)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: chart.layoutDirection) { _, _ in
                            haptic.impactOccurred()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Alarm Block")
                                .font(.custom("ChartflowHand-Regular", size: 24))
                                .foregroundStyle(Color.chartflowText)
                            Spacer()
                            Toggle("", isOn: $chart.alarmEnabled)
                                .labelsHidden()
                                .onChange(of: chart.alarmEnabled) { _, enabled in
                                    haptic.impactOccurred()
                                    if enabled {
                                        if chart.alarmHour == nil {
                                            chart.alarmHour = 7
                                            chart.alarmMinute = 0
                                            chart.alarmIsAM = true
                                            alarmHour = 7
                                            alarmMinute = 0
                                            alarmIsAM = true
                                        }
                                        showAlarmPicker = true
                                    } else {
                                        UNUserNotificationCenter.current()
                                            .removePendingNotificationRequests(withIdentifiers: ["alarm"])
                                    }
                                }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        if chart.alarmEnabled {
                            Button {
                                alarmHour = chart.alarmHour ?? 7
                                alarmMinute = chart.alarmMinute ?? 0
                                alarmIsAM = chart.alarmIsAM
                                showAlarmPicker = true
                                haptic.impactOccurred()
                            } label: {
                                Text(formattedAlarm())
                                    .font(.custom("ChartflowHand-Regular", size: 18))
                                    .foregroundStyle(Color.chartflowSecondaryText)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }

                    Spacer()
                }
                .frame(width: 240)
                .background(Color.chartflowSurface)
                .ignoresSafeArea()

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .offset(x: showSideMenu ? 0 : -260)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            chart.ensureDynamicConfiguration()
            if chart.scheduleType == .dynamic && chart.dynamicConfiguration?.setupCompleted == false {
                showDynamicSetupWizard = true
            }
            zoomScale = CGFloat(defaultZoom)
            requestNotificationPermission()
            UNUserNotificationCenter.current().delegate = notificationDelegate
            restoreActiveRoutineSnapshot()
            if let h = chart.alarmHour {
                alarmHour = h
                alarmMinute = chart.alarmMinute ?? 0
                alarmIsAM = chart.alarmIsAM
            }
        }
        .onDisappear {
            saveActiveRoutineSnapshot()
            progressStore.commitSave()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && isRunning && !isPaused {
                synchronizeTimerWithCurrentDate()
                if isRunning {
                    scheduleTimer()
                }
            }
        }
        .onChange(of: notificationDelegate.shouldStartTimer) { _, should in
            if should && !isRunning {
                startTimer()
                notificationDelegate.shouldStartTimer = false
            }
        }
        .sheet(isPresented: $showDynamicSetupWizard) {
            DynamicScheduleWizardView(chart: $chart)
                .interactiveDismissDisabled(chart.dynamicConfiguration?.setupCompleted == false)
        }
        .sheet(isPresented: $showAlarmPicker) {
            VStack(spacing: 16) {
                Text("Set Alarm Time")
                    .font(.custom("ChartflowHand-Regular", size: 22))
                    .fontWeight(.bold)
                    .padding(.top, 24)

                HStack(spacing: 0) {
                    Picker("Hour", selection: $alarmHour) {
                        ForEach(1...12, id: \.self) { h in
                            Text("\(h)")
                                .font(.custom("ChartflowHand-Regular", size: 18))
                                .tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()

                    Text(":")
                        .font(.custom("ChartflowHand-Regular", size: 24))

                    Picker("Minute", selection: $alarmMinute) {
                        ForEach(0...59, id: \.self) { m in
                            Text(String(format: "%02d", m))
                                .font(.custom("ChartflowHand-Regular", size: 18))
                                .tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()

                    Picker("AM/PM", selection: $alarmIsAM) {
                        Text("AM").tag(true)
                        Text("PM").tag(false)
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()
                }
                .frame(height: 180)

                Button {
                    chart.alarmHour = alarmHour
                    chart.alarmMinute = alarmMinute
                    chart.alarmIsAM = alarmIsAM
                    scheduleAlarmNotification()
                    showAlarmPicker = false
                    haptic.impactOccurred()
                } label: {
                    Text("Set Alarm")
                        .font(.custom("ChartflowHand-Regular", size: 18))
                        .foregroundStyle(Color.chartflowBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.chartflowText)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }
            .presentationDetents([.height(340)])
        }
    }
}

// Alarm block view
struct AlarmBlockView: View {
    @Binding var chart: Chart
    var layoutDirection: ChartLayoutDirection = .leftToRight
    @AppStorage("largerText") private var largerText = false

    var alarmText: String {
        guard let h = chart.alarmHour, let m = chart.alarmMinute else { return "No time set" }
        return String(format: "%d:%02d %@", h, m, chart.alarmIsAM ? "AM" : "PM")
    }

    var body: some View {
        VStack(spacing: 4) {
            TasqIcon("alarm.fill", size: 14)
                .foregroundStyle(Color.chartflowSecondaryText)
            Text("Alarm")
                .font(.custom("ChartflowHand-Regular", size: largerText ? 16 : 14))
                .foregroundStyle(Color.chartflowSecondaryText)
            Text(alarmText)
                .font(.custom("ChartflowHand-Regular", size: largerText ? 14 : 12))
                .foregroundStyle(Color.chartflowSecondaryText)
        }
        .frame(minWidth: layoutDirection == .topToBottom ? 220 : 100)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .chartflowBox(cornerRadius: 16, wobble: 2, fillColor: Color.chartflowSecondaryText.opacity(0.15), strokeColor: .chartflowSecondaryText, lineWidth: 2)
        .padding(.horizontal, 8)
    }
}

// Grey polka dot background pattern
struct PolkaDotBackground: View {
    let dotSize: CGFloat = 4
    let spacing: CGFloat = 24
    @AppStorage("backgroundPattern") private var backgroundPatternRaw = TasqBackgroundPattern.dots.rawValue

    var body: some View {
        let pattern = TasqBackgroundPattern(rawValue: backgroundPatternRaw) ?? .dots

        ZStack {
            Color.chartflowBackground

            Canvas { context, size in
                switch pattern {
                case .dots:
                    let columns = Int(size.width / spacing) + 2
                    let rows = Int(size.height / spacing) + 2
                    for row in 0..<rows {
                        for col in 0..<columns {
                            let x = CGFloat(col) * spacing
                            let y = CGFloat(row) * spacing
                            let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                            context.fill(Path(ellipseIn: rect), with: .color(Color.chartflowPattern))
                        }
                    }
                case .squares:
                    let columns = Int(size.width / spacing) + 2
                    let rows = Int(size.height / spacing) + 2
                    for row in 0..<rows {
                        for col in 0..<columns {
                            let x = CGFloat(col) * spacing
                            let y = CGFloat(row) * spacing
                            let rect = CGRect(x: x, y: y, width: dotSize + 1, height: dotSize + 1)
                            context.fill(Path(rect), with: .color(Color.chartflowPattern))
                        }
                    }
                case .bigCircles:
                    let circles: [(CGFloat, CGFloat, CGFloat)] = [
                        (0.12, 0.18, 180),
                        (0.76, 0.14, 220),
                        (0.38, 0.48, 260),
                        (0.86, 0.64, 210),
                        (0.18, 0.86, 240)
                    ]
                    for circle in circles {
                        let rect = CGRect(
                            x: size.width * circle.0 - circle.2 / 2,
                            y: size.height * circle.1 - circle.2 / 2,
                            width: circle.2,
                            height: circle.2
                        )
                        context.stroke(Path(ellipseIn: rect), with: .color(Color.chartflowPattern.opacity(0.55)), lineWidth: 2)
                    }
                case .none:
                    break
                }
            }
        }
    }
}

// A single flowchart-style box
struct FlowNodeView: View {
    @Binding var event: ChartEvent
    var isEditingAll: Bool
    var canDelete: Bool
    var isRunning: Bool
    var isCurrentTask: Bool
    var finishTimeText: String? = nil
    var onAdd: () -> Void
    var onDelete: () -> Void
    var onComplete: () -> Void
    var isSubtask: Bool = false
    var layoutDirection: ChartLayoutDirection = .leftToRight
    @State private var showDurationPicker = false
    @AppStorage("largerText") private var largerText = false
    @AppStorage("boldText") private var boldText = false

    let haptic = UIImpactFeedbackGenerator(style: .medium)
    let successHaptic = UINotificationFeedbackGenerator()

    var fontSize: CGFloat {
        if isSubtask {
            return largerText ? 15 : 13
        }
        return largerText ? 19 : 16
    }
    var minWidthValue: CGFloat {
        if isSubtask { return 140 }
        return layoutDirection == .topToBottom ? 220 : 100
    }

    let minuteOptions = Array(stride(from: 1, through: 180, by: 1))

    var fillColor: Color {
        if isRunning {
            return (isCurrentTask && event.isCompleted) ? Color.green.opacity(0.4) : Color.chartflowSurface
        } else {
            return event.isCompleted ? Color.green.opacity(0.4) : Color.chartflowSurface
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 4) {
                if isEditingAll {
                    TextField("Name", text: $event.name)
                        .font(.custom("ChartflowHand-Regular", size: fontSize))
                        .fontWeight(boldText ? .bold : .regular)
                        .foregroundStyle(Color.chartflowText)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    Text(event.name.isEmpty ? " " : event.name)
                        .font(.custom("ChartflowHand-Regular", size: fontSize))
                        .fontWeight(boldText ? .bold : .regular)
                        .foregroundStyle(Color.chartflowText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if !isSubtask {
                    Text("\(event.durationMinutes) min")
                        .font(.custom("ChartflowHand-Regular", size: fontSize - 4))
                        .fontWeight(boldText ? .semibold : .regular)
                        .foregroundStyle(Color.chartflowText.opacity(0.7))
                        .underline(!isRunning)
                        .onTapGesture {
                            if !isRunning {
                                haptic.impactOccurred()
                                showDurationPicker = true
                            }
                        }

                    if let finishTimeText {
                        Text(finishTimeText)
                            .font(.custom("ChartflowHand-Regular", size: fontSize - 5))
                            .fontWeight(boldText ? .semibold : .regular)
                            .foregroundStyle(Color.chartflowText.opacity(0.55))
                    }
                }
            }
            .frame(minWidth: minWidthValue)
            .padding(.vertical, isSubtask ? 8 : 12)
            .padding(.horizontal, isSubtask ? 10 : 16)
            .chartflowBox(
                cornerRadius: 16,
                wobble: 2,
                fillColor: fillColor,
                strokeColor: isCurrentTask && isRunning ? Color.blue : Color.chartflowText,
                lineWidth: isSubtask ? 1.5 : 2
            )
            .overlay(alignment: .topTrailing) {
                if !isSubtask && !isRunning {
                    Button {
                        onAdd()
                    } label: {
                        TasqIcon("plus.circle.fill", size: 18)
                            .foregroundStyle(Color.chartflowText)
                            .background(Color.chartflowSurface)
                            .clipShape(Circle())
                    }
                    .offset(x: 6, y: -6)
                }
            }
            .overlay(alignment: .topLeading) {
                if canDelete && !isRunning {
                    Button {
                        onDelete()
                    } label: {
                        TasqIcon("minus.circle.fill", size: isSubtask ? 14 : 18)
                            .foregroundStyle(.red)
                            .background(Color.chartflowSurface)
                            .clipShape(Circle())
                    }
                    .offset(x: -6, y: -6)
                }
            }
            .onTapGesture {
                if isRunning {
                    if isCurrentTask && !isSubtask {
                        successHaptic.notificationOccurred(.success)
                        withAnimation(.easeInOut(duration: 1.0)) {
                            event.isCompleted = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onComplete()
                        }
                    }
                } else if !isEditingAll {
                    haptic.impactOccurred()
                    withAnimation(.easeInOut(duration: 1.0)) {
                        event.isCompleted.toggle()
                    }
                }
            }
            .animation(.easeInOut(duration: 1.0), value: event.isCompleted)
            .sheet(isPresented: $showDurationPicker) {
                VStack(spacing: 16) {
                    Text("Set Duration")
                        .font(.custom("ChartflowHand-Regular", size: 22))
                        .fontWeight(.bold)
                        .padding(.top, 24)

                    Picker("Duration", selection: $event.durationMinutes) {
                        ForEach(minuteOptions, id: \.self) { minute in
                            Text("\(minute) min")
                                .font(.custom("ChartflowHand-Regular", size: 18))
                                .tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 180)

                    Button {
                        showDurationPicker = false
                        haptic.impactOccurred()
                    } label: {
                        Text("Done")
                            .font(.custom("ChartflowHand-Regular", size: 18))
                            .foregroundStyle(Color.chartflowBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.chartflowText)
                            .cornerRadius(14)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 24)
                }
                .presentationDetents([.height(300)])
            }

            if !isRunning {
                Button {
                    let newSubtask = ChartEvent(name: "", durationMinutes: 10)
                    event.subtasks.append(newSubtask)
                    haptic.impactOccurred()
                } label: {
                    TasqIcon("plus", size: 10)
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }

            if !event.subtasks.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(event.subtasks.enumerated()), id: \.element.id) { subIndex, _ in
                        FlowNodeView(
                            event: $event.subtasks[subIndex],
                            isEditingAll: isEditingAll,
                            canDelete: true,
                            isRunning: isRunning,
                            isCurrentTask: isCurrentTask,
                            onAdd: { },
                            onDelete: {
                                event.subtasks.remove(at: subIndex)
                                haptic.impactOccurred()
                            },
                            onComplete: { },
                            isSubtask: true
                        )

                        if subIndex < event.subtasks.count - 1 {
                            ConnectorView()
                                .padding(.top, 20)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

// Connector line + arrow between boxes
struct ConnectorView: View {
    var direction: ChartLayoutDirection = .leftToRight

    var body: some View {
        switch direction {
        case .leftToRight:
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.chartflowText)
                    .frame(width: 16, height: 2)
                TasqIcon("arrowtriangle.right.fill", size: 10)
                    .foregroundStyle(Color.chartflowText)
                    .offset(x: -4)
            }
        case .topToBottom:
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.chartflowText)
                    .frame(width: 2, height: 16)
                TasqIcon("arrowtriangle.down.fill", size: 10)
                    .foregroundStyle(Color.chartflowText)
                    .offset(y: -4)
            }
        }
    }
}

#Preview {
    ChartEditorView(chart: .constant(Chart.sample), defaultZoom: 1.3)
}
