//
//  ChartEditorView.swift
//  Tasq
//

import SwiftUI
import UserNotifications
internal import Combine

struct ChartEditorView: View {
    @Binding var chart: Chart
    let defaultZoom: Double
    var startImmediately = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var progressStore: UserProgressStore
    @ObservedObject private var notifications = TasqNotificationRouter.shared
    @State private var showFlowDuringRun = false
    @State private var showCompletion = false
    @State private var showStopConfirmation = false
    @State private var hasPrepared = false
    @State private var notificationsUnavailable = false
    @State private var zoomScale: CGFloat = 1.3
    @State private var isEditingAll = false
    @State private var isEditingTitle = false
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { notificationsUnavailable = !granted }
        }
    }

    private func notificationID(_ kind: String) -> String {
        TasqNotificationRouter.identifier(chartID: chart.id, kind: kind)
    }

    private var routineNotificationIdentifiers: [String] {
        chart.events.indices.map { notificationID("task-\($0)") }
            + [notificationID("complete"), notificationID("complete-now")]
    }

    private var activeRoutineSnapshotKey: String {
        ActiveRoutineSnapshot.key(for: chart.id)
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

        scheduleRoutineCompleteNotification(after: max(1, delay), identifier: notificationID("complete"))
    }

    func scheduleTaskNotification(for index: Int, after delay: TimeInterval, isFirstVisibleTask: Bool) {
        guard chart.events.indices.contains(index) else { return }
        let event = chart.events[index]
        let content = UNMutableNotificationContent()
        content.title = "Tasq"
        content.userInfo = ["chartID": chart.id.uuidString, "kind": "task"]
        content.body = isFirstVisibleTask
            ? "Starting: \(event.name.isEmpty ? "Task \(index + 1)" : event.name)"
            : "Time for: \(event.name.isEmpty ? "Task \(index + 1)" : event.name)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_loop.caf"))
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: notificationID("task-\(index)"), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleRoutineCompleteNotification(after delay: TimeInterval = 1, identifier: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Tasq"
        content.userInfo = ["chartID": chart.id.uuidString, "kind": "complete"]
        content.body = "All tasks complete in \(chart.name)."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: identifier ?? notificationID("complete-now"), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleAlarmNotification() {
        TasqNotificationRouter.scheduleAlarm(for: chart)
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
        guard !chart.events.isEmpty else { return }
        requestNotificationPermission()
        showCompletion = false
        showFlowDuringRun = false
        for i in chart.events.indices {
            chart.events[i].isCompleted = false
            chart.events[i].isMissed = false
            for j in chart.events[i].subtasks.indices {
                chart.events[i].subtasks[j].isCompleted = false
                chart.events[i].subtasks[j].isMissed = false
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
        guard isRunning else { return }
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
            if !isPaused { scheduleNotifications(from: nextIndex) }
            saveActiveRoutineSnapshot()
            scheduleTimer()
        } else {
            completeRoutine(sendNotification: true)
        }
    }

    func synchronizeTimerWithCurrentDate(sendCompletionNotification: Bool = false) {
        guard isRunning, !isPaused, let routineStartDate else { return }
        let elapsed = max(0, Int(Date().timeIntervalSince(routineStartDate)))
        guard let position = RoutineClock.position(events: chart.events, elapsed: elapsed) else {
            completeRoutine(sendNotification: sendCompletionNotification)
            return
        }
        for index in chart.events.indices where index < position.index {
            chart.events[index].isCompleted = true
        }
        if currentEventIndex != position.index { haptic.impactOccurred() }
        currentEventIndex = position.index
        taskStartDate = routineStartDate.addingTimeInterval(TimeInterval(position.elapsedBeforeTask))
        secondsRemaining = position.secondsRemaining
        saveActiveRoutineSnapshot()
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
        showCompletion = true
        progressStore.commitSave()
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
                scheduleNotifications(from: currentEventIndex, currentTaskRemaining: secondsRemaining)
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
                guard isRunning, currentEventIndex == index else { return }
                advanceToNext()
            },
            layoutDirection: chart.layoutDirection
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            if showCompletion {
                completionContent
            } else if isRunning && !showFlowDuringRun {
                focusContent
            } else {
                if chart.scheduleType == .dynamic && !isRunning {
                    Button { showDynamicSetupWizard = true } label: {
                        Label("Adjust my dynamic plan", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DoodleButtonStyle(tint: .tasqLilac))
                    .padding(.horizontal, 20).padding(.bottom, 12)
                }
                if chart.events.isEmpty {
                    VStack(spacing: 18) {
                        Text("Let's give your day a little shape.")
                            .doodleFont(26, relativeTo: .title2)
                        Button("Set up my plan") { showDynamicSetupWizard = true }
                            .buttonStyle(DoodleButtonStyle(prominent: true))
                    }
                    .padding(25).frame(maxHeight: .infinity)
                } else {
                    GeometryReader { geometry in
                        ScrollView([.vertical, .horizontal]) {
                            chartFlowContent
                                .padding(.horizontal, flowHorizontalPadding)
                                .padding(.vertical, flowVerticalPadding)
                                .scaleEffect(zoomScale)
                                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                        }
                    }
                }
            }
        }
        .foregroundStyle(Color.chartflowText)
        .background(PolkaDotBackground().ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !showCompletion { routineControls }
        }
        .overlay {
            if showConfetti {
                ConfettiView().ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !hasPrepared {
                hasPrepared = true
                chart.ensureDynamicConfiguration()
                zoomScale = CGFloat(defaultZoom)
                let hadSnapshot = ActiveRoutineSnapshot.load(chartID: chart.id) != nil
                restoreActiveRoutineSnapshot()
                if chart.scheduleType == .dynamic && chart.dynamicConfiguration?.setupCompleted == false {
                    showDynamicSetupWizard = true
                } else if startImmediately && !hadSnapshot {
                    startTimer()
                }
                if notifications.requestedChartID == chart.id { notifications.requestedChartID = nil }
            } else if isRunning && !isPaused {
                synchronizeTimerWithCurrentDate()
                if isRunning { scheduleTimer() }
            }
            alarmHour = chart.alarmHour ?? 7
            alarmMinute = chart.alarmMinute ?? 0
            alarmIsAM = chart.alarmIsAM
        }
        .onDisappear {
            saveActiveRoutineSnapshot()
            timer?.invalidate()
            timer = nil
            progressStore.commitSave()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isRunning && !isPaused {
                synchronizeTimerWithCurrentDate()
                if isRunning { scheduleTimer() }
            } else if phase != .active {
                saveActiveRoutineSnapshot()
                timer?.invalidate()
                timer = nil
            }
        }
        .onChange(of: notifications.requestedChartID) { _, id in
            guard id == chart.id else { return }
            if notifications.startsRoutine && !isRunning { startTimer() }
            notifications.requestedChartID = nil
        }
        .confirmationDialog("Stop this routine?", isPresented: $showStopConfirmation, titleVisibility: .visible) {
            Button("Stop routine", role: .destructive) { stopTimer() }
            Button("Keep going", role: .cancel) { }
        } message: { Text("You can pause it instead and come back whenever you're ready.") }
        .sheet(isPresented: $showDynamicSetupWizard) { DynamicScheduleWizardView(chart: $chart) }
        .sheet(isPresented: $showAlarmPicker) { alarmPicker }
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 7) {
                        TasqIcon("chevron.left", size: 15)
                        Text("Tasq")
                    }.frame(minHeight: 44)
                }
                .accessibilityLabel("Back to Tasq")
                .accessibilityHint(isRunning ? "Your routine keeps its progress." : "")
                Spacer()
                if isRunning {
                    Button { showFlowDuringRun.toggle() } label: {
                        Text(showFlowDuringRun ? "Focus view" : "See my plan")
                            .frame(minHeight: 44)
                    }
                } else {
                    Menu {
                        Picker("Layout", selection: $chart.layoutDirection) {
                            Text("Across the page").tag(ChartLayoutDirection.leftToRight)
                            Text("Down the page").tag(ChartLayoutDirection.topToBottom)
                        }
                        Button(chart.alarmEnabled ? "Change reminder" : "Add a reminder", systemImage: "alarm") {
                            showAlarmPicker = true
                        }
                        if chart.alarmEnabled {
                            Button("Turn off reminder", systemImage: "bell.slash") {
                                chart.alarmEnabled = false
                                scheduleAlarmNotification()
                            }
                        }
                    } label: { TasqIcon("ellipsis", size: 22).frame(width: 44, height: 44) }
                    .accessibilityLabel("Routine settings")
                }
            }
            .doodleFont(18, relativeTo: .body)
            if isEditingTitle && !isRunning {
                TextField("Routine name", text: $chart.name)
                    .doodleFont(30, relativeTo: .title).bold()
                    .submitLabel(.done)
                    .onSubmit { finishRenaming() }
            } else {
                HStack(spacing: 10) {
                    Text(chart.name).doodleFont(30, relativeTo: .title).bold()
                    if !isRunning && !showCompletion {
                        Button { isEditingTitle = true } label: {
                            TasqIcon("pencil", size: 17).frame(width: 44, height: 44)
                        }.accessibilityLabel("Rename routine")
                    }
                }
            }
            if !isRunning && !showCompletion && chart.alarmEnabled {
                Text(notificationsUnavailable ? "Notifications are off in iOS Settings." : "Daily nudge · \(formattedAlarm())")
                    .doodleFont(16, relativeTo: .caption)
                    .foregroundStyle(Color.chartflowSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 22).padding(.bottom, 12)
        .background(Color.chartflowBackground)
    }

    private var focusContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                DoodleBadge(title: isPaused ? "A LITTLE BREATHER" : "JUST THIS ONE THING")
                VStack(spacing: 18) {
                    Text("Step \(currentEventIndex + 1) of \(chart.events.count)")
                        .doodleFont(18, relativeTo: .subheadline)
                    Text(currentEvent?.name.isEmpty == false ? currentEvent!.name : "Task \(currentEventIndex + 1)")
                        .doodleFont(34, relativeTo: .title).bold()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(formattedTime(secondsRemaining))
                        .doodleFont(68, relativeTo: .largeTitle)
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .accessibilityLabel("\(secondsRemaining / 60) minutes, \(secondsRemaining % 60) seconds remaining")
                    Text(isPaused ? "Paused. Take the time you need." : "One small step is enough for right now.")
                        .doodleFont(18, relativeTo: .body)
                        .multilineTextAlignment(.center)
                    ProgressView(value: Double(currentEventIndex), total: Double(max(1, chart.events.count)))
                        .tint(Color.chartflowText)
                        .accessibilityLabel("Routine progress")
                }
                .padding(26).frame(maxWidth: .infinity)
                .chartflowBox(cornerRadius: 28, wobble: 1.4, fillColor: .tasqSage,
                              strokeColor: .chartflowText, lineWidth: 1.8)

                if let event = currentEvent, !event.subtasks.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Little steps").doodleFont(22, relativeTo: .headline).bold()
                        ForEach(event.subtasks.indices, id: \.self) { index in
                            Button {
                                chart.events[currentEventIndex].subtasks[index].isCompleted.toggle()
                            } label: {
                                HStack(spacing: 14) {
                                    TasqIcon(event.subtasks[index].isCompleted ? "checkmark.circle.fill" : "circle", size: 20)
                                    Text(event.subtasks[index].name.isEmpty ? "Step \(index + 1)" : event.subtasks[index].name)
                                        .strikethrough(event.subtasks[index].isCompleted)
                                    Spacer()
                                }
                                .doodleFont(20, relativeTo: .body)
                                .frame(minHeight: 46).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .accessibilityValue(event.subtasks[index].isCompleted ? "Complete" : "Incomplete")
                        }
                    }.padding(20)
                        .chartflowBox(fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.3)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("UP NEXT").doodleFont(14, relativeTo: .caption).bold()
                    if chart.events.indices.contains(currentEventIndex + 1) {
                        let next = chart.events[currentEventIndex + 1]
                        Text("\(next.name.isEmpty ? "Next task" : next.name) · \(next.durationMinutes) min")
                            .doodleFont(22, relativeTo: .body)
                    } else {
                        Text("A little celebration. This is your last step.")
                            .doodleFont(22, relativeTo: .body)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if notificationsUnavailable {
                    Text("Notifications are off. Enable them in iOS Settings for task reminders while Tasq is closed.")
                        .doodleFont(16, relativeTo: .callout)
                        .foregroundStyle(Color.chartflowSecondaryText)
                }
            }
            .padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
    }

    private var routineControls: some View {
        VStack(spacing: 12) {
            if isRunning {
                if showFlowDuringRun {
                    Text("\(isPaused ? "Paused · " : "")\(formattedTime(secondsRemaining)) remaining")
                        .doodleFont(24, relativeTo: .title2)
                }
                HStack(spacing: 12) {
                    Button {
                        if isPaused { resumeTimer() } else { pauseTimer() }
                    } label: {
                        Text(isPaused ? "Resume" : "Pause").frame(maxWidth: .infinity)
                    }.buttonStyle(DoodleButtonStyle())
                    Button { advanceToNext() } label: {
                        HStack {
                            Text(currentEventIndex == chart.events.count - 1 ? "Finish" : "Done")
                            TasqIcon("checkmark", size: 16)
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(DoodleButtonStyle(prominent: true))
                }
                Button("Stop routine") { showStopConfirmation = true }
                    .doodleFont(16, relativeTo: .caption)
                    .foregroundStyle(Color.chartflowSecondaryText)
                    .frame(minHeight: 44)
            } else {
                HStack(spacing: 16) {
                    Button { zoomScale = max(0.5, zoomScale - 0.1) } label: {
                        TasqIcon("minus.magnifyingglass", size: 20).frame(width: 44, height: 44)
                    }.accessibilityLabel("Zoom out")
                    Text("\(Int(zoomScale * 100))%")
                        .doodleFont(17, relativeTo: .body)
                    Button { zoomScale = min(2, zoomScale + 0.1) } label: {
                        TasqIcon("plus.magnifyingglass", size: 20).frame(width: 44, height: 44)
                    }.accessibilityLabel("Zoom in")
                    Spacer()
                    Text("\(chart.totalMinutes) min")
                        .doodleFont(18, relativeTo: .body)
                }
                HStack(spacing: 12) {
                    Button {
                        finishRenaming()
                        isEditingAll.toggle()
                    } label: { Text(isEditingAll ? "Save edits" : "Edit plan") }
                        .buttonStyle(DoodleButtonStyle())
                        .disabled(chart.events.isEmpty)
                    Button {
                        finishRenaming()
                        isEditingAll = false
                        startTimer()
                    } label: { Text("Start routine").frame(maxWidth: .infinity) }
                        .buttonStyle(DoodleButtonStyle(prominent: true))
                        .disabled(chart.events.isEmpty)
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 8)
        .foregroundStyle(Color.chartflowText)
        .background(Color.chartflowBackground)
        .overlay(alignment: .top) { Rectangle().fill(Color.chartflowText.opacity(0.15)).frame(height: 1) }
    }

    private var completionContent: some View {
        ScrollView {
            VStack(spacing: 23) {
                DoodleSun()
                DoodleBadge(title: "LOOK AT YOU GO")
                Text("A little effort.\nA lovely finish.")
                    .doodleFont(38, relativeTo: .largeTitle).bold()
                    .multilineTextAlignment(.center)
                Text("You've reached the end of \(chart.name). Take a moment for yourself.")
                    .doodleFont(22, relativeTo: .body)
                    .multilineTextAlignment(.center)
                Button("Back to my day") { dismiss() }
                    .buttonStyle(DoodleButtonStyle(prominent: true))
                Button("See my plan") { showCompletion = false }
                    .buttonStyle(DoodleButtonStyle())
            }
            .padding(28).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
    }

    private var alarmPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                DoodleSectionTitle(title: "A gentle nudge", subtitle: "A daily reminder to start this routine.")
                HStack(spacing: 0) {
                    Picker("Hour", selection: $alarmHour) {
                        ForEach(1...12, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Text(":")
                    Picker("Minute", selection: $alarmMinute) {
                        ForEach(0...59, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    Picker("AM/PM", selection: $alarmIsAM) {
                        Text("AM").tag(true)
                        Text("PM").tag(false)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 170)
                .padding(12)
                .chartflowBox(fillColor: .tasqLilac, strokeColor: .chartflowText, lineWidth: 1.5)
                Button {
                    requestNotificationPermission()
                    chart.alarmHour = alarmHour
                    chart.alarmMinute = alarmMinute
                    chart.alarmIsAM = alarmIsAM
                    chart.alarmEnabled = true
                    scheduleAlarmNotification()
                    progressStore.commitSave()
                    showAlarmPicker = false
                } label: { Text("Save reminder").frame(maxWidth: .infinity) }
                    .buttonStyle(DoodleButtonStyle(prominent: true))
                Button("Cancel") { showAlarmPicker = false }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .doodleFont(20, relativeTo: .body)
            .foregroundStyle(Color.chartflowText)
            .padding(26).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .background(PolkaDotBackground().ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func finishRenaming() {
        if chart.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { chart.name = "Untitled Routine" }
        isEditingTitle = false
        progressStore.commitSave()
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
                        event.isCompleted = true
                        onComplete()
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
