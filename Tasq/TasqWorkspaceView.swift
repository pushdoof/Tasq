import SwiftUI
import UserNotifications

/// The app's shared home. Future features can join the same navigation and theme.
struct TasqWorkspaceView: View {
    @Binding var charts: [Chart]
    @Binding var defaultZoom: Double
    @EnvironmentObject private var progressStore: UserProgressStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSpace = TasqSpace.today
    @State private var editor: RoutineDestination?
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var showNewRoutine = false
    @State private var deletingChart: Chart?
    @State private var search = ""
    @State private var snapshotRefresh = Date()
    @ObservedObject private var notifications = TasqNotificationRouter.shared

    private var activeChart: Chart? {
        _ = snapshotRefresh
        let unfinished = charts.first {
            guard let snapshot = ActiveRoutineSnapshot.load(chartID: $0.id) else { return false }
            return !snapshot.hasFinished(events: $0.events)
        }
        return unfinished ?? charts.first { ActiveRoutineSnapshot.load(chartID: $0.id) != nil }
    }

    private var featuredChart: Chart? { activeChart ?? charts.first }

    private var filteredCharts: [Chart] {
        charts.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if selectedSpace == .friends {
                FriendHubView(embedded: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        if selectedSpace == .today { todayContent } else { routineLibrary }
                    }
                    .padding(22)
                    .frame(maxWidth: 740)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(PolkaDotBackground().ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .sheet(isPresented: $showSettings) { SettingsView(defaultZoom: $defaultZoom) }
        .sheet(isPresented: $showHelp) {
            OnboardingView(hasSeenOnboarding: .constant(true), defaultZoom: $defaultZoom,
                           showsSkipButton: false) { showHelp = false }
        }
        .sheet(isPresented: $showNewRoutine, onDismiss: {
            if let id = pendingNewChartID {
                pendingNewChartID = nil
                editor = RoutineDestination(id: id, startImmediately: false)
            }
        }) {
            NewRoutineSheet { chart in
                charts.append(chart)
                progressStore.commitSave()
                showNewRoutine = false
                // Present the editor after the creation sheet has closed.
                pendingNewChartID = chart.id
            }
        }
        .fullScreenCover(item: $editor, onDismiss: { snapshotRefresh = .now }) { destination in
            if let chart = charts.first(where: { $0.id == destination.id }) {
                NavigationStack {
                    ChartEditorView(chart: binding(for: chart), defaultZoom: defaultZoom,
                                    startImmediately: destination.startImmediately)
                }
            } else {
                ContentUnavailableView("Routine unavailable", systemImage: "note.text",
                                       description: Text("This routine may have been removed on another device."))
                    .overlay(alignment: .bottom) { Button("Back to Tasq") { editor = nil }.padding(30) }
            }
        }
        .confirmationDialog("Delete this routine?", isPresented: Binding(
            get: { deletingChart != nil }, set: { if !$0 { deletingChart = nil } }
        ), titleVisibility: .visible) {
            if let chart = deletingChart {
                Button("Delete \(chart.name)", role: .destructive) { delete(chart) }
            }
            Button("Cancel", role: .cancel) { deletingChart = nil }
        } message: { Text("The routine and its reminders will be removed.") }
        .onAppear {
            charts.forEach { TasqNotificationRouter.scheduleAlarm(for: $0) }
            openNotification()
        }
        .onChange(of: notifications.requestedChartID) { _, _ in openNotification() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { snapshotRefresh = .now }
        }
    }

    @State private var pendingNewChartID: UUID?

    private var header: some View {
        HStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Tasq").doodleFont(35, relativeTo: .title)
                    .fontWeight(.black)
                Text("a little every day")
                    .doodleFont(15, relativeTo: .caption)
                    .foregroundStyle(Color.chartflowSecondaryText)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Button { showSettings = true } label: {
                TasqIcon("gearshape.fill", size: 21).frame(width: 46, height: 46)
                    .chartflowBox(cornerRadius: 15, wobble: 1, fillColor: .chartflowSurface,
                                  strokeColor: .chartflowText, lineWidth: 1.4)
            }
            .accessibilityLabel("Settings")
        }
        .foregroundStyle(Color.chartflowText)
        .padding(.horizontal, 22).padding(.vertical, 10)
        .background(Color.chartflowBackground)
    }

    private var todayContent: some View {
        Group {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .doodleFont(17, relativeTo: .subheadline)
                        .foregroundStyle(Color.chartflowSecondaryText)
                    Text("Make space for your day.")
                        .doodleFont(34, relativeTo: .largeTitle)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                DoodleSun()
            }

            if let chart = featuredChart {
                featuredRoutine(chart)
            } else {
                firstRoutineCard
            }

            if let error = progressStore.errorMessage {
                Label("Sync needs attention: \(error)", systemImage: "exclamationmark.icloud")
                    .doodleFont(16, relativeTo: .callout)
                    .padding(16)
                    .chartflowBox(fillColor: .tasqPeach, strokeColor: .chartflowText)
            }

            if !charts.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        DoodleSectionTitle(title: "Your routines", subtitle: "Small steps, at your own pace.")
                        Button("See all") { selectedSpace = .routines }
                            .doodleFont(18, relativeTo: .body)
                            .frame(minHeight: 44)
                    }
                    ForEach(charts.prefix(3)) { chart in routineRow(chart) }
                }
            }

            Button { selectedSpace = .friends } label: {
                HStack(spacing: 18) {
                    TasqIcon("person.2.fill", size: 28).frame(width: 44)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("A little company")
                            .doodleFont(25, relativeTo: .title2).bold()
                        Text("Check in, chat, and cheer each other on.")
                            .doodleFont(17, relativeTo: .body)
                    }
                    Spacer(minLength: 0)
                    TasqIcon("chevron.right", size: 16)
                }
                .padding(21)
                .chartflowBox(cornerRadius: 22, wobble: 1.8, fillColor: .tasqPeach,
                              strokeColor: .chartflowText, lineWidth: 1.6)
            }
            .buttonStyle(.plain)

            futureFeatures
        }
        .foregroundStyle(Color.chartflowText)
    }

    private func featuredRoutine(_ chart: Chart) -> some View {
        let snapshot = ActiveRoutineSnapshot.load(chartID: chart.id)
        let finished = snapshot?.hasFinished(events: chart.events) == true
        return VStack(alignment: .leading, spacing: 17) {
            HStack {
                DoodleBadge(title: snapshot == nil ? "ONE THING AT A TIME" : finished ? "A LOVELY FINISH" : "PICK UP HERE", tint: .chartflowSurface)
                Spacer()
                TasqIcon("sparkles", size: 23)
            }
            Text(chart.name)
                .doodleFont(32, relativeTo: .title).bold()
            Text(snapshot == nil
                 ? "\(chart.events.count) steps · \(chart.totalMinutes) min · you've got this."
                 : finished ? "Your routine has reached the end. Take a moment to look back."
                 : snapshot?.isPaused == true ? "Your routine is paused. Ready when you are." : "Your routine is underway. Come back to your next step.")
                .doodleFont(18, relativeTo: .body)
            Button { open(chart, start: true) } label: {
                HStack {
                    Text(snapshot == nil ? "Start routine" : finished ? "Review routine" : "Return to routine")
                    Spacer()
                    TasqIcon("play.fill", size: 19)
                }
            }
            .buttonStyle(DoodleButtonStyle(prominent: true))
        }
        .padding(23)
        .chartflowBox(cornerRadius: 24, wobble: 2, fillColor: .tasqSage,
                      strokeColor: .chartflowText, lineWidth: 1.8)
    }

    private var firstRoutineCard: some View {
        VStack(alignment: .leading, spacing: 17) {
            DoodleBadge(title: "YOUR FIRST LITTLE STEP", tint: .chartflowSurface)
            Text("A fresh page. A doable plan.")
                .doodleFont(30, relativeTo: .title).bold()
            Text("Try a ready-made routine, or draw one that feels like you.")
                .doodleFont(19, relativeTo: .body)
            Button { showNewRoutine = true } label: {
                Label("Make my first routine", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(DoodleButtonStyle(prominent: true))
        }
        .padding(23)
        .chartflowBox(cornerRadius: 24, wobble: 2, fillColor: .tasqSage,
                      strokeColor: .chartflowText, lineWidth: 1.8)
    }

    private var routineLibrary: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                DoodleSectionTitle(title: "Your routines", subtitle: "Chartflow, your way.")
                Button { showHelp = true } label: {
                    TasqIcon("questionmark.circle", size: 22).frame(width: 44, height: 44)
                }.accessibilityLabel("Routine guide")
            }
            Button { showNewRoutine = true } label: {
                Label("New routine", systemImage: "plus").frame(maxWidth: .infinity)
            }.buttonStyle(DoodleButtonStyle(prominent: true))

            if charts.isEmpty {
                Text("Morning rituals, study sessions, a softer end to the day. Start with a template and make it yours.")
                    .doodleFont(22, relativeTo: .body)
                    .padding(22)
                    .chartflowBox(fillColor: .tasqSage, strokeColor: .chartflowText)
            } else {
                HStack {
                    TasqIcon("magnifyingglass", size: 18)
                    TextField("Find a routine", text: $search)
                        .doodleFont(20, relativeTo: .body)
                        .submitLabel(.search)
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            TasqIcon("xmark", size: 14).frame(width: 44, height: 44)
                        }.accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 16).frame(minHeight: 56)
                .chartflowBox(fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.3)
                if filteredCharts.isEmpty {
                    Text("No routines with that name yet.")
                        .doodleFont(21, relativeTo: .body)
                }
                ForEach(filteredCharts) { chart in routineRow(chart) }
            }
        }
        .foregroundStyle(Color.chartflowText)
    }

    private func routineRow(_ chart: Chart) -> some View {
        HStack(spacing: 12) {
            Button { open(chart, start: false) } label: {
                HStack(spacing: 16) {
                    TasqIcon(chart.scheduleType == .dynamic ? "wand.and.stars" : "list.bullet.rectangle", size: 24)
                        .frame(width: 35)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(chart.name).doodleFont(23, relativeTo: .headline).bold()
                        Text("\(chart.events.count) steps · \(chart.totalMinutes) min")
                            .doodleFont(16, relativeTo: .subheadline)
                            .foregroundStyle(Color.chartflowSecondaryText)
                        if let snapshot = ActiveRoutineSnapshot.load(chartID: chart.id) {
                            Text(snapshot.hasFinished(events: chart.events) ? "Ready to review" : snapshot.isPaused ? "Paused" : "In progress").doodleFont(15, relativeTo: .caption).bold()
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
            Menu {
                Button("Start or resume", systemImage: "play") { open(chart, start: true) }
                Button("Edit routine", systemImage: "pencil") { open(chart, start: false) }
                Button("Duplicate", systemImage: "plus.square.on.square") {
                    var copy = chart
                    copy.id = UUID()
                    copy.name += " copy"
                    copy.alarmEnabled = false
                    copy.events = copy.events.map { event in
                        var reset = event
                        reset.isCompleted = false
                        reset.isMissed = false
                        reset.subtasks = reset.subtasks.map { subtask in
                            var child = subtask
                            child.isCompleted = false
                            child.isMissed = false
                            return child
                        }
                        return reset
                    }
                    charts.append(copy)
                    progressStore.commitSave()
                }
                Button("Delete", systemImage: "trash", role: .destructive) { deletingChart = chart }
            } label: {
                TasqIcon("ellipsis", size: 21).frame(width: 44, height: 44)
            }.accessibilityLabel("Options for \(chart.name)")
        }
        .foregroundStyle(Color.chartflowText)
        .padding(18)
        .chartflowBox(cornerRadius: 20, wobble: 1.5, fillColor: .chartflowSurface,
                      strokeColor: .chartflowText, lineWidth: 1.4)
    }

    private var futureFeatures: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Room to grow").doodleFont(24, relativeTo: .title2).bold()
                Spacer()
                DoodleBadge(title: "COMING LATER", tint: .tasqLilac)
            }
            futureRow("Diary", detail: "A little space to reflect on your day.", icon: "book.closed")
            futureRow("AI helper", detail: "A helping hand with what comes next.", icon: "sparkles")
        }
        .padding(20)
        .chartflowBox(cornerRadius: 22, wobble: 1, fillColor: .chartflowSurface,
                      strokeColor: .chartflowText.opacity(0.4), lineWidth: 1.2)
    }

    private func futureRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 16) {
            TasqIcon(icon, size: 22).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).doodleFont(21, relativeTo: .headline).bold()
                Text(detail).doodleFont(16, relativeTo: .body)
                    .foregroundStyle(Color.chartflowSecondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). Coming later. \(detail)")
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(TasqSpace.allCases) { space in
                Button { selectedSpace = space } label: {
                    VStack(spacing: 6) {
                        TasqIcon(space.icon, size: 21).frame(height: 26)
                        Text(space.rawValue)
                            .doodleFont(16, relativeTo: .caption).bold()
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .chartflowBox(cornerRadius: 16, wobble: selectedSpace == space ? 1.2 : 0,
                                  fillColor: selectedSpace == space ? space.tint : .clear,
                                  strokeColor: selectedSpace == space ? .chartflowText : .clear, lineWidth: 1.5)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedSpace == space ? .isSelected : [])
            }
        }
        .foregroundStyle(Color.chartflowText)
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
        .background(Color.chartflowBackground)
        .overlay(alignment: .top) { Rectangle().fill(Color.chartflowText.opacity(0.15)).frame(height: 1) }
    }

    private func binding(for chart: Chart) -> Binding<Chart> {
        Binding {
            charts.first(where: { $0.id == chart.id }) ?? chart
        } set: { updated in
            guard let index = charts.firstIndex(where: { $0.id == chart.id }) else { return }
            charts[index] = updated
        }
    }

    private func open(_ chart: Chart, start: Bool) {
        editor = RoutineDestination(id: chart.id, startImmediately: start)
    }

    private func openNotification() {
        guard let id = notifications.requestedChartID,
              let chart = charts.first(where: { $0.id == id }) else { return }
        open(chart, start: notifications.startsRoutine)
    }

    private func delete(_ chart: Chart) {
        TasqNotificationRouter.removeNotifications(for: chart.id)
        UserDefaults.standard.removeObject(forKey: ActiveRoutineSnapshot.key(for: chart.id))
        charts.removeAll { $0.id == chart.id }
        deletingChart = nil
        progressStore.commitSave()
    }
}

private struct RoutineDestination: Identifiable {
    let id: UUID
    let startImmediately: Bool
}

private enum TasqSpace: String, CaseIterable, Identifiable {
    case today = "Today", routines = "Routines", friends = "Friends"
    var id: Self { self }
    var icon: String {
        switch self {
        case .today: return "house.fill"
        case .routines: return "list.bullet.rectangle"
        case .friends: return "person.2.fill"
        }
    }
    var tint: Color { self == .friends ? .tasqPeach : .tasqSage }
}

private struct NewRoutineSheet: View {
    let create: (Chart) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    DoodleSectionTitle(title: "Make a little plan", subtitle: "Start somewhere. Make it yours.")
                    Button { dismiss() } label: { TasqIcon("xmark", size: 18).frame(width: 44, height: 44) }
                        .accessibilityLabel("Close new routine")
                }
                choice("Draw your own", detail: "Build a flowchart, one task at a time.", icon: "pencil", tint: .tasqSage) {
                    create(.blank())
                }
                choice("Fit it into my day", detail: "Pick a time window. Arrange tasks around it.", icon: "wand.and.stars", tint: .tasqLilac) {
                    create(.blank(type: .dynamic))
                }
                DoodleSectionTitle(title: "Borrow a starting point", subtitle: "Everything can be edited later.")
                ForEach(RoutineTemplate.allCases) { template in
                    choice(template.rawValue, detail: template.detail, icon: template.icon, tint: .chartflowSurface) {
                        create(template.makeChart())
                    }
                }
            }
            .padding(25)
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .background(PolkaDotBackground().ignoresSafeArea())
        .foregroundStyle(Color.chartflowText)
        .presentationDragIndicator(.visible)
    }

    private func choice(_ title: String, detail: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 17) {
                TasqIcon(icon, size: 25).frame(width: 35)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).doodleFont(24, relativeTo: .headline).bold()
                    Text(detail).doodleFont(17, relativeTo: .body)
                        .foregroundStyle(Color.chartflowSecondaryText)
                }
                Spacer(minLength: 0)
                TasqIcon("chevron.right", size: 15)
            }.padding(19)
                .chartflowBox(cornerRadius: 20, wobble: 1.5, fillColor: tint, strokeColor: .chartflowText, lineWidth: 1.5)
        }.buttonStyle(.plain)
    }
}

enum RoutineTemplate: String, CaseIterable, Identifiable {
    case morning = "An easy morning", focus = "A little focus", evening = "Wind down"
    var id: Self { self }
    var detail: String {
        switch self {
        case .morning: return "Stretch, get ready, have breakfast · 30 min"
        case .focus: return "Set up, focus, take a break · 35 min"
        case .evening: return "Tidy up, get ready, read · 30 min"
        }
    }
    var icon: String {
        switch self {
        case .morning: return "sun.max"
        case .focus: return "pencil"
        case .evening: return "moon"
        }
    }
    func makeChart() -> Chart {
        let tasks: [(String, Int)]
        switch self {
        case .morning: tasks = [("Stretch & sip some water", 5), ("Get ready", 10), ("Breakfast", 15)]
        case .focus: tasks = [("Clear your space", 5), ("One thing to focus on", 25), ("Take a breather", 5)]
        case .evening: tasks = [("A little tidy-up", 5), ("Get ready for bed", 10), ("Read & unwind", 15)]
        }
        return Chart(name: rawValue, events: tasks.map { ChartEvent(name: $0.0, durationMinutes: $0.1) }, layoutDirection: .topToBottom)
    }
}

extension Chart {
    var totalMinutes: Int { events.reduce(0) { $0 + $1.durationMinutes } }
}
