import SwiftUI

struct DynamicScheduleWizardView: View {
    @Binding var chart: Chart
    @State private var draftChart = Chart.blank(type: .dynamic)
    @Environment(\.dismiss) private var dismiss
    @State private var step = DynamicScheduleWizardStep.window

    private var canGoBack: Bool {
        step.previous != nil
    }

    private var isLastStep: Bool {
        step.next == nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                wizardHeader

                TabView(selection: $step) {
                    windowStep
                        .tag(DynamicScheduleWizardStep.window)

                    tasksStep
                        .tag(DynamicScheduleWizardStep.tasks)

                    prioritiesStep
                        .tag(DynamicScheduleWizardStep.priorities)

                    configurationStep
                        .tag(DynamicScheduleWizardStep.configuration)

                    reviewStep
                        .tag(DynamicScheduleWizardStep.review)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                wizardFooter
            }
            .background(PolkaDotBackground().ignoresSafeArea())
            .navigationTitle("A plan that fits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            draftChart = chart
            draftChart.ensureDynamicConfiguration()
            draftChart.regenerateDynamicEvents()
        }
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(DynamicScheduleWizardStep.allCases) { wizardStep in
                    Capsule()
                        .fill(wizardStep.rawValue <= step.rawValue ? Color.chartflowText : Color.chartflowSecondaryText.opacity(0.25))
                        .frame(height: 7)
                }
            }

            Text(step.title)
                .font(.custom("ChartflowHand-Regular", size: 30))
                .fontWeight(.bold)
                .foregroundStyle(Color.chartflowText)

            Text(step.subtitle)
                .font(.custom("ChartflowHand-Regular", size: 16))
                .foregroundStyle(Color.chartflowSecondaryText)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(Color.chartflowSurface)
    }

    private var planIssue: String? {
        Chart.dynamicPlan(from: draftChart.dynamicConfiguration ?? .standard).issue
    }

    private var wizardFooter: some View {
      VStack(spacing: 10) {
        if let issue = planIssue {
            Text(issue)
                .doodleFont(17, relativeTo: .callout)
                .foregroundStyle(Color.chartflowText)
                .padding(14)
                .chartflowBox(fillColor: .tasqPeach, strokeColor: .chartflowText, lineWidth: 1.2)
                .padding(.horizontal, 22)
        }
        HStack(spacing: 12) {
            Button {
                if let previous = step.previous {
                    withAnimation { step = previous }
                }
            } label: {
                Label {
                    Text("Back")
                } icon: {
                    TasqIcon("chevron.left", size: 18)
                }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DoodleButtonStyle())
            .disabled(!canGoBack)

            Button {
                if let next = step.next {
                    draftChart.regenerateDynamicEvents()
                    withAnimation { step = next }
                } else {
                    completeSetup()
                }
            } label: {
                Label {
                    Text(isLastStep ? "Done" : "Next")
                } icon: {
                    TasqIcon(isLastStep ? "checkmark.circle.fill" : "chevron.right", size: 18)
                }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DoodleButtonStyle(prominent: true))
            .disabled(isLastStep && planIssue != nil)
        }
        .font(.custom("ChartflowHand-Regular", size: 18))
        .padding(18)
        .background(Color.chartflowSurface)
      }
    }

    private var windowStep: some View {
        WizardScrollContent {
            DynamicTimePickerRow(
                title: "Start",
                hour: configurationBinding(\.startHour),
                minute: configurationBinding(\.startMinute),
                isAM: configurationBinding(\.startIsAM),
                onChange: regenerateEvents
            )

            DynamicTimePickerRow(
                title: "End",
                hour: configurationBinding(\.endHour),
                minute: configurationBinding(\.endMinute),
                isAM: configurationBinding(\.endIsAM),
                onChange: regenerateEvents
            )
        }
    }

    private var tasksStep: some View {
        WizardScrollContent {
            if let tasks = draftChart.dynamicConfiguration?.dailyTasks {
                ForEach(tasks.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        TextField("Daily thing", text: taskNameBinding(at: index))
                            .textFieldStyle(.plain)
                            .doodleFont(21, relativeTo: .body)
                            .padding(16)
                            .chartflowBox(fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.3)
                            .onChange(of: draftChart.dynamicConfiguration?.dailyTasks[index].name ?? "") { _, _ in regenerateEvents() }

                        if tasks.count > 1 {
                            Button(role: .destructive) {
                                draftChart.dynamicConfiguration?.dailyTasks.remove(at: index)
                                draftChart.regenerateDynamicEvents()
                            } label: {
                                TasqIcon("minus.circle.fill", size: 20)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Button {
                draftChart.dynamicConfiguration?.dailyTasks.append(
                    DynamicScheduleTask(name: "", timeRank: 2, importanceRank: 3)
                )
                draftChart.regenerateDynamicEvents()
            } label: {
                Label {
                    Text("Add Daily Thing")
                } icon: {
                    TasqIcon("plus.circle.fill", size: 18)
                }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DoodleButtonStyle())
        }
    }

    private var prioritiesStep: some View {
        WizardScrollContent {
            Text("Time rank 1 gets the most time. Importance 5 goes first. Pinned tasks stay at their chosen time.")
                .padding(16)
                .chartflowBox(fillColor: .tasqLilac, strokeColor: .chartflowText, lineWidth: 1.2)
            if let tasks = draftChart.dynamicConfiguration?.dailyTasks {
                ForEach(tasks.indices, id: \.self) { index in
                    DynamicScheduleTaskRow(
                        task: taskBinding(at: index),
                        canDelete: false,
                        onDelete: { },
                        onChange: regenerateEvents
                    )
                }
            }
        }
    }

    private var configurationStep: some View {
        WizardScrollContent {
            Stepper(value: configurationBinding(\.minimumTaskMinutes), in: 1...30, step: 1) {
                Text("Minimum task: \(draftChart.dynamicConfiguration?.minimumTaskMinutes ?? 5) min")
            }
            .onChange(of: draftChart.dynamicConfiguration?.minimumTaskMinutes ?? 5) { _, _ in regenerateEvents() }

            VStack(alignment: .leading, spacing: 10) {
                Text("Priority emphasis: \(draftChart.dynamicConfiguration?.importanceBias ?? 1.0, specifier: "%.1f")x")
                Slider(value: configurationBinding(\.importanceBias), in: 0.5...2.0, step: 0.1)
                    .onChange(of: draftChart.dynamicConfiguration?.importanceBias ?? 1.0) { _, _ in regenerateEvents() }
            }

            Toggle("Show start times in task names", isOn: configurationBinding(\.includeStartTimesInTitles))
                .onChange(of: draftChart.dynamicConfiguration?.includeStartTimesInTitles ?? true) { _, _ in regenerateEvents() }
        }
    }

    private var reviewStep: some View {
        WizardScrollContent {
            Text("The whole window is accounted for. Empty gaps appear as free time. Start this routine at the planned time to follow these clock times.")
                .padding(16)
                .chartflowBox(fillColor: .tasqSage, strokeColor: .chartflowText, lineWidth: 1.2)
            Button {
                draftChart.regenerateDynamicEvents()
            } label: {
                Label {
                    Text("Regenerate")
                } icon: {
                    TasqIcon("arrow.triangle.2.circlepath", size: 18)
                }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DoodleButtonStyle())

            ForEach(draftChart.events) { event in
                HStack(alignment: .firstTextBaseline) {
                    Text(event.name.isEmpty ? "Task" : event.name)
                        .foregroundStyle(Color.chartflowText)
                    Spacer()
                    Text("\(event.durationMinutes) min")
                        .foregroundStyle(Color.chartflowSecondaryText)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .chartflowBox(cornerRadius: 15, wobble: 1, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.2)
            }
        }
    }

    private func taskNameBinding(at index: Int) -> Binding<String> {
        Binding {
            draftChart.dynamicConfiguration?.dailyTasks[index].name ?? ""
        } set: { newValue in
            guard draftChart.dynamicConfiguration?.dailyTasks.indices.contains(index) == true else { return }
            draftChart.dynamicConfiguration?.dailyTasks[index].name = newValue
        }
    }

    private func taskBinding(at index: Int) -> Binding<DynamicScheduleTask> {
        Binding {
            draftChart.dynamicConfiguration?.dailyTasks[index] ?? DynamicScheduleTask(name: "", timeRank: 2, importanceRank: 3)
        } set: { newValue in
            guard draftChart.dynamicConfiguration?.dailyTasks.indices.contains(index) == true else { return }
            draftChart.dynamicConfiguration?.dailyTasks[index] = newValue
        }
    }

    private func configurationBinding<Value>(_ keyPath: WritableKeyPath<DynamicScheduleConfiguration, Value>) -> Binding<Value> {
        Binding {
            let configuration = draftChart.dynamicConfiguration ?? .standard
            return configuration[keyPath: keyPath]
        } set: { newValue in
            var configuration = draftChart.dynamicConfiguration ?? .standard
            configuration[keyPath: keyPath] = newValue
            draftChart.dynamicConfiguration = configuration
        }
    }

    private func regenerateEvents() {
        draftChart.regenerateDynamicEvents()
    }

    private func completeSetup() {
        guard planIssue == nil else { return }
        var configuration = draftChart.dynamicConfiguration ?? .standard
        configuration.setupCompleted = true
        draftChart.dynamicConfiguration = configuration
        draftChart.regenerateDynamicEvents()
        chart = draftChart
        dismiss()
    }
}

private enum DynamicScheduleWizardStep: Int, CaseIterable, Identifiable {
    case window
    case tasks
    case priorities
    case configuration
    case review

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .window: return "Pick the Time Slot"
        case .tasks: return "Add Daily Things"
        case .priorities: return "Rank and Pin"
        case .configuration: return "Make It Your Own"
        case .review: return "Review the Plan"
        }
    }

    var subtitle: String {
        switch self {
        case .window: return "Choose when this dynamic schedule should fit into the day."
        case .tasks: return "List the things you normally do every day."
        case .priorities: return "Rank time needed, importance, and any exact start times."
        case .configuration: return "Choose the shortest step and how much priorities matter."
        case .review: return "Check the tentative schedule before using it."
        }
    }

    var previous: DynamicScheduleWizardStep? {
        DynamicScheduleWizardStep(rawValue: rawValue - 1)
    }

    var next: DynamicScheduleWizardStep? {
        DynamicScheduleWizardStep(rawValue: rawValue + 1)
    }
}

private struct WizardScrollContent<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .font(.custom("ChartflowHand-Regular", size: 16))
            .foregroundStyle(Color.chartflowText)
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DynamicScheduleTaskRow: View {
    @Binding var task: DynamicScheduleTask
    let canDelete: Bool
    let onDelete: () -> Void
    let onChange: () -> Void
    @State private var hasFixedStartTime = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(task.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Daily Thing" : task.name)
                    .font(.custom("ChartflowHand-Regular", size: 19))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.chartflowText)
                Spacer()
                if canDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        TasqIcon("minus.circle.fill", size: 20)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Stepper(value: $task.timeRank, in: 1...5) {
                Label {
                    Text("Time rank: \(task.timeRank)")
                } icon: {
                    TasqIcon("clock", size: 17)
                }
            }
            .onChange(of: task.timeRank) { _, _ in onChange() }

            Stepper(value: $task.importanceRank, in: 1...5) {
                Label {
                    Text("Importance: \(task.importanceRank)")
                } icon: {
                    TasqIcon("exclamationmark.circle", size: 17)
                }
            }
            .onChange(of: task.importanceRank) { _, _ in onChange() }

            Toggle("Specific start time", isOn: $hasFixedStartTime)
                .onChange(of: hasFixedStartTime) { _, enabled in
                    if enabled {
                        task.fixedStartHour = task.fixedStartHour ?? 8
                        task.fixedStartMinute = task.fixedStartMinute ?? 0
                    } else {
                        task.fixedStartHour = nil
                        task.fixedStartMinute = nil
                    }
                    onChange()
                }

            if hasFixedStartTime {
                DynamicTimePickerRow(
                    title: "Pinned",
                    hour: fixedHourBinding,
                    minute: fixedMinuteBinding,
                    isAM: $task.fixedStartIsAM,
                    onChange: onChange
                )
            }
        }
        .padding(14)
        .chartflowBox(cornerRadius: 18, wobble: 1.3, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.3)
        .onAppear {
            hasFixedStartTime = task.hasFixedStartTime
        }
        .font(.custom("ChartflowHand-Regular", size: 16))
    }

    private var fixedHourBinding: Binding<Int> {
        Binding {
            task.fixedStartHour ?? 8
        } set: { newValue in
            task.fixedStartHour = newValue
        }
    }

    private var fixedMinuteBinding: Binding<Int> {
        Binding {
            task.fixedStartMinute ?? 0
        } set: { newValue in
            task.fixedStartMinute = newValue
        }
    }
}

struct DynamicTimePickerRow: View {
    let title: String
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var isAM: Bool
    let onChange: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.chartflowText)
            Spacer()
            Picker("Hour", selection: $hour) {
                ForEach(1...12, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            .onChange(of: hour) { _, _ in onChange() }

            Picker("Minute", selection: $minute) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            .onChange(of: minute) { _, _ in onChange() }

            Picker("AM/PM", selection: $isAM) {
                Text("AM").tag(true)
                Text("PM").tag(false)
            }
            .frame(maxWidth: .infinity)
            .clipped()
            .onChange(of: isAM) { _, _ in onChange() }
        }
        .padding(14)
        .chartflowBox(cornerRadius: 18, wobble: 1.3, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.3)
    }
}

#Preview {
    DynamicScheduleWizardView(chart: .constant(.blank(type: .dynamic)))
}
