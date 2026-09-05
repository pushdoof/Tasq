import SwiftUI

struct DynamicScheduleWizardView: View {
    @Binding var chart: Chart
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
            .background(Color.chartflowBackground.ignoresSafeArea())
            .navigationTitle("Dynamic Setup")
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
            chart.ensureDynamicConfiguration()
            chart.regenerateDynamicEvents()
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

    private var wizardFooter: some View {
        HStack(spacing: 12) {
            Button {
                if let previous = step.previous {
                    withAnimation { step = previous }
                }
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!canGoBack)

            Button {
                if let next = step.next {
                    chart.regenerateDynamicEvents()
                    withAnimation { step = next }
                } else {
                    completeSetup()
                }
            } label: {
                Label(isLastStep ? "Done" : "Next", systemImage: isLastStep ? "checkmark.circle.fill" : "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .font(.custom("ChartflowHand-Regular", size: 18))
        .padding(18)
        .background(Color.chartflowSurface)
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
            if let tasks = chart.dynamicConfiguration?.dailyTasks {
                ForEach(tasks.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        TextField("Daily thing", text: taskNameBinding(at: index))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: chart.dynamicConfiguration?.dailyTasks[index].name ?? "") { _, _ in regenerateEvents() }

                        if tasks.count > 1 {
                            Button(role: .destructive) {
                                chart.dynamicConfiguration?.dailyTasks.remove(at: index)
                                chart.regenerateDynamicEvents()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Button {
                chart.dynamicConfiguration?.dailyTasks.append(
                    DynamicScheduleTask(name: "", timeRank: 2, importanceRank: 3)
                )
                chart.regenerateDynamicEvents()
            } label: {
                Label("Add Daily Thing", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var prioritiesStep: some View {
        WizardScrollContent {
            if let tasks = chart.dynamicConfiguration?.dailyTasks {
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
                Text("Minimum task: \(chart.dynamicConfiguration?.minimumTaskMinutes ?? 5) min")
            }
            .onChange(of: chart.dynamicConfiguration?.minimumTaskMinutes ?? 5) { _, _ in regenerateEvents() }

            VStack(alignment: .leading, spacing: 10) {
                Text("Importance Bias: \(chart.dynamicConfiguration?.importanceBias ?? 1.0, specifier: "%.1f")x")
                Slider(value: configurationBinding(\.importanceBias), in: 0.5...2.0, step: 0.1)
                    .onChange(of: chart.dynamicConfiguration?.importanceBias ?? 1.0) { _, _ in regenerateEvents() }
            }

            Toggle("Show start times in task names", isOn: configurationBinding(\.includeStartTimesInTitles))
                .onChange(of: chart.dynamicConfiguration?.includeStartTimesInTitles ?? true) { _, _ in regenerateEvents() }
        }
    }

    private var reviewStep: some View {
        WizardScrollContent {
            Button {
                chart.regenerateDynamicEvents()
            } label: {
                Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            ForEach(chart.events) { event in
                HStack(alignment: .firstTextBaseline) {
                    Text(event.name.isEmpty ? "Task" : event.name)
                        .foregroundStyle(Color.chartflowText)
                    Spacer()
                    Text("\(event.durationMinutes) min")
                        .foregroundStyle(Color.chartflowSecondaryText)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.chartflowSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func taskNameBinding(at index: Int) -> Binding<String> {
        Binding {
            chart.dynamicConfiguration?.dailyTasks[index].name ?? ""
        } set: { newValue in
            guard chart.dynamicConfiguration?.dailyTasks.indices.contains(index) == true else { return }
            chart.dynamicConfiguration?.dailyTasks[index].name = newValue
        }
    }

    private func taskBinding(at index: Int) -> Binding<DynamicScheduleTask> {
        Binding {
            chart.dynamicConfiguration?.dailyTasks[index] ?? DynamicScheduleTask(name: "", timeRank: 2, importanceRank: 3)
        } set: { newValue in
            guard chart.dynamicConfiguration?.dailyTasks.indices.contains(index) == true else { return }
            chart.dynamicConfiguration?.dailyTasks[index] = newValue
        }
    }

    private func configurationBinding<Value>(_ keyPath: WritableKeyPath<DynamicScheduleConfiguration, Value>) -> Binding<Value> {
        Binding {
            let configuration = chart.dynamicConfiguration ?? .standard
            return configuration[keyPath: keyPath]
        } set: { newValue in
            var configuration = chart.dynamicConfiguration ?? .standard
            configuration[keyPath: keyPath] = newValue
            chart.dynamicConfiguration = configuration
        }
    }

    private func regenerateEvents() {
        chart.regenerateDynamicEvents()
    }

    private func completeSetup() {
        var configuration = chart.dynamicConfiguration ?? .standard
        configuration.setupCompleted = true
        chart.dynamicConfiguration = configuration
        chart.regenerateDynamicEvents()
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
        case .configuration: return "Tune the Generator"
        case .review: return "Review the Plan"
        }
    }

    var subtitle: String {
        switch self {
        case .window: return "Choose when this dynamic schedule should fit into the day."
        case .tasks: return "List the things you normally do every day."
        case .priorities: return "Rank time needed, importance, and any exact start times."
        case .configuration: return "Adjust how strict and visible the generated plan should be."
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
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Stepper(value: $task.timeRank, in: 1...5) {
                Label("Time rank: \(task.timeRank)", systemImage: "clock")
            }
            .onChange(of: task.timeRank) { _, _ in onChange() }

            Stepper(value: $task.importanceRank, in: 1...5) {
                Label("Importance: \(task.importanceRank)", systemImage: "exclamationmark.circle")
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
        .background(Color.chartflowSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .frame(width: 72)
            .clipped()
            .onChange(of: hour) { _, _ in onChange() }

            Picker("Minute", selection: $minute) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .frame(width: 82)
            .clipped()
            .onChange(of: minute) { _, _ in onChange() }

            Picker("AM/PM", selection: $isAM) {
                Text("AM").tag(true)
                Text("PM").tag(false)
            }
            .frame(width: 88)
            .clipped()
            .onChange(of: isAM) { _, _ in onChange() }
        }
        .padding(14)
        .background(Color.chartflowSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    DynamicScheduleWizardView(chart: .constant(.blank(type: .dynamic)))
}
