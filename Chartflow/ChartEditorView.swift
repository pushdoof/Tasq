//
//  ContentView.swift
//  Chartflow
//

import SwiftUI
internal import Combine


struct ContentView: View {
    @State private var chart = Chart(name: "Untitled Routine", events: [
        ChartEvent(name: "", durationMinutes: 10)
    ])
    @State private var zoomScale: CGFloat = 1.0
    @State private var isEditingAll = false
    @State private var showSideMenu = false
    @State private var optionSelected = false
    @State private var isEditingTitle = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            withAnimation {
                                showSideMenu.toggle()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 22))
                                .foregroundStyle(.black)
                        }
                        .padding(.leading, 20)

                        Spacer()
                    }
                    .padding(.top, 12)

                    HStack(spacing: 8) {
                        if isEditingTitle {
                            TextField("Chart Name", text: $chart.name, onCommit: {
                                isEditingTitle = false
                            })
                            .font(.custom("ChartflowHand-Regular", size: 34))
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                            .textFieldStyle(.plain)
                        } else {
                            Text(chart.name)
                                .font(.custom("ChartflowHand-Regular", size: 34))
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                        }
                        
                        Button {
                            if isEditingTitle {
                                if chart.name.trimmingCharacters(in: .whitespaces).isEmpty {
                                    chart.name = "Untitled Routine"
                                }
                            }
                            isEditingTitle.toggle()
                        } label: {
                            Image(systemName: isEditingTitle ? "checkmark.circle" : "pencil.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    ScrollView(.vertical) {
                        GeometryReader { geometry in
                            ScrollView(.horizontal) {
                                HStack(alignment: .top, spacing: 0) {
                                    ForEach(Array(chart.events.enumerated()), id: \.element.id) { index, event in
                                        FlowNodeView(
                                            event: $chart.events[index],
                                            isEditingAll: isEditingAll,
                                            canDelete: chart.events.count > 1,
                                            onAdd: {
                                                let newEvent = ChartEvent(name: "", durationMinutes: 10)
                                                chart.events.insert(newEvent, at: index + 1)
                                            },
                                            onDelete: {
                                                chart.events.remove(at: index)
                                            }
                                        )

                                        if index < chart.events.count - 1 {
                                            ConnectorView()
                                                .padding(.top, 30)
                                        }
                                    }
                                }
                                .padding(.horizontal, 60 * zoomScale * zoomScale * zoomScale)
                                .scaleEffect(zoomScale)
                                .padding(.vertical, 40 * zoomScale * zoomScale * zoomScale)
                                .frame(minWidth: geometry.size.width)
                            }
                        }
                        .frame(height: 400)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PolkaDotBackground())

                    // Zoom controls
                    HStack(spacing: 20) {
                        Button {
                            withAnimation {
                                zoomScale = max(0.5, zoomScale - 0.1)
                            }
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 20))
                        }

                        Text("\(Int(zoomScale * 100))%")
                            .font(.custom("ChartflowHand-Regular", size: 16))
                            .frame(width: 50)

                        Button {
                            withAnimation {
                                zoomScale = min(2.0, zoomScale + 0.1)
                            }
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.bottom, 16)
                    .padding(.top, 12)
                    .foregroundStyle(.black)
                    .background(Color.white)
                }
                .background(
                    Color.white.ignoresSafeArea()
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Big global edit pencil button, bottom-left
                Button {
                    isEditingAll.toggle()
                } label: {
                    Image(systemName: isEditingAll ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(isEditingAll ? Color.blue : Color.black)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .padding(.leading, 20)
                .padding(.bottom, 80)

                // Dimmed background when side menu is open (tap to close)
                if showSideMenu {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showSideMenu = false
                            }
                        }
                        .animation(.easeInOut(duration: 0.25), value: showSideMenu)
                }
                // Side menu
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 80)

                        Text("Home")
                            .font(.custom("ChartflowHand-Regular", size: 24))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(optionSelected ? Color.gray.opacity(0.3) : Color.clear)
                            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressing in
                                optionSelected = isPressing
                            }, perform: { })

                        Spacer()
                    }
                    .frame(width: 220)
                    .background(Color.white)
                    .ignoresSafeArea()

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .offset(x: showSideMenu ? 0 : -240)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// Grey polka dot background pattern
struct PolkaDotBackground: View {
    let dotSize: CGFloat = 4
    let spacing: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            let columns = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2

            for row in 0..<rows {
                for col in 0..<columns {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.gray.opacity(0.3)))
                }
            }
        }
        .background(Color.white)
    }
}

// A single flowchart-style box (recursive: can show subtasks below it)
struct FlowNodeView: View {
    @Binding var event: ChartEvent
    var isEditingAll: Bool
    var canDelete: Bool
    var onAdd: () -> Void
    var onDelete: () -> Void
    var isSubtask: Bool = false
    @State private var refreshTrigger = false
    @State private var isCompleted = false

    var fontSize: CGFloat { isSubtask ? 13 : 16 }
    var minWidthValue: CGFloat { isSubtask ? 70 : 100 }

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 4) {
                if isEditingAll {
                    TextField("Name", text: $event.name)
                        .font(.custom("ChartflowHand-Regular", size: fontSize))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    Text(event.name.isEmpty ? " " : event.name)
                        .font(.custom("ChartflowHand-Regular", size: fontSize))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: true, vertical: false)
                }
                Text("\(event.durationMinutes) min")
                    .font(.custom("ChartflowHand-Regular", size: fontSize - 4))
                    .foregroundStyle(.gray)
            }
            .frame(minWidth: minWidthValue)
            .padding(.vertical, isSubtask ? 8 : 12)
            .padding(.horizontal, isSubtask ? 10 : 16)
            .background(
                WobblyRectangle(cornerRadius: 16, wobble: 2)
                    .fill(isCompleted ? Color.green.opacity(0.4) : Color.white)
                    .padding(1)
                    .id(refreshTrigger)
            )
            .overlay(
                WobblyRectangle(cornerRadius: 16, wobble: 2)
                    .stroke(Color.black, lineWidth: isSubtask ? 1.5 : 2)
                    .padding(1)
                    .id(refreshTrigger)
            )
            .overlay(alignment: .topTrailing) {
                if !isSubtask {
                    Button {
                        onAdd()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.black)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .offset(x: 6, y: -6)
                }
            }
            .overlay(alignment: .topLeading) {
                if canDelete {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: isSubtask ? 14 : 18))
                            .foregroundStyle(.red)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .offset(x: -6, y: -6)
                }
            }
            .onReceive(Timer.publish(every: 0.10, on: .main, in: .common).autoconnect()) { _ in
                refreshTrigger.toggle()
            }
            .onTapGesture {
                if !isEditingAll {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        isCompleted.toggle()
                    }
                }
            }
            .animation(.easeInOut(duration: 1.0), value: isCompleted)

            Button {
                let newSubtask = ChartEvent(name: "", durationMinutes: 5)
                event.subtasks.append(newSubtask)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray.opacity(0.5))
            }

            if !event.subtasks.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(event.subtasks.enumerated()), id: \.element.id) { subIndex, _ in
                        FlowNodeView(
                            event: $event.subtasks[subIndex],
                            isEditingAll: isEditingAll,
                            canDelete: true,
                            onAdd: { },
                            onDelete: {
                                event.subtasks.remove(at: subIndex)
                            },
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

// Connector line + arrow between boxes (horizontal)
struct ConnectorView: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.black)
                .frame(width: 16, height: 2)
            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 10))
                .foregroundStyle(.black)
                .offset(x: -4)
        }
    }
}

#Preview {
    ContentView()
}
