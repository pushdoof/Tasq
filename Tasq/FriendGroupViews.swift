import SwiftUI
internal import Combine

struct FriendGroupHubView: View {
    let account: FriendHubAccount
    let friends: [FriendHubAccount]
    @StateObject private var store = FriendGroupStore()
    @State private var creating = false
    @State private var listMode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reduceBoxMotion") private var reduceBoxMotion = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your little universe").doodleFont(26).bold()
                    Text(store.groups.isEmpty ? "A little place for you and your friends." : "Drag a bubble. Drop in on your people.")
                        .doodleFont(16).foregroundStyle(Color.chartflowSecondaryText)
                }
                Spacer(minLength: 0)
                Button { listMode.toggle() } label: {
                    Image(systemName: listMode ? "circle.grid.2x2" : "list.bullet")
                        .frame(width: 44, height: 44)
                }.accessibilityLabel(listMode ? "Show group bubbles" : "Show groups as a list")
            }.padding(.horizontal, 20)
            Button { creating = true } label: {
                Label("Create a group", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(DoodleButtonStyle(tint: .tasqSage))
            .padding(.horizontal, 20)
            .layoutPriority(1)
            .accessibilityIdentifier("friendHubCreateGroup")
            if store.isLoading {
                ProgressView("Finding your groups…").frame(maxHeight: .infinity)
            } else if store.groups.isEmpty {
                ScrollView {
                    VStack(spacing: 14) {
                        ZStack {
                            WobblyCircle(wobble: 2).fill(Color.tasqLilac)
                            WobblyCircle(wobble: 2).stroke(Color.chartflowText, lineWidth: 1.5)
                            VStack(spacing: 0) {
                                HStack(spacing: -28) {
                                    FriendGroupSprite(avatar: .fallback).rotationEffect(.degrees(-12))
                                    FriendGroupSprite(avatar: .fallback).rotationEffect(.degrees(12))
                                }.frame(width: 150, height: 110)
                                Text("Room for your people").doodleFont(18).bold()
                            }
                        }.frame(width: 220, height: 220)
                        Text("Make your first circle") .doodleFont(25).bold()
                        Text("Choose a few friends, name your group,\nand make a little place to hang out.")
                            .doodleFont(18).multilineTextAlignment(.center)
                            .foregroundStyle(Color.chartflowSecondaryText)
                        if friends.isEmpty {
                            Text("Start your group now, or find people in Search and add them later.")
                                .doodleFont(16).multilineTextAlignment(.center)
                        }
                    }.padding(20).frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if listMode || reduceMotion || reduceBoxMotion {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.groups) { group in
                            Button { store.selectedGroupID = group.id } label: {
                                HStack {
                                    FriendGroupSprite(avatar: .fallback).frame(width: 55, height: 60)
                                    VStack(alignment: .leading) {
                                        Text(group.name).doodleFont(22).bold()
                                        Text("\(group.memberIDs.count) people · \(group.rooms.count) rooms").doodleFont(16)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }.padding(14).groupCard(.tasqLilac)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 20)
                }
            } else {
                FriendGroupBubbleField(groups: store.groups) { store.selectedGroupID = $0.id }
            }
            if !store.errorMessage.isEmpty { FriendGroupErrorBanner(message: store.errorMessage) }
        }
        .foregroundStyle(Color.chartflowText)
        .task(id: account.id) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-friend-hub-preview") {
                store.prepareVisualCheck(account: account,
                    empty: ProcessInfo.processInfo.arguments.contains("-empty-groups"))
                return
            }
            #endif
            store.start(account: account)
        }
        .sheet(isPresented: $creating) {
            FriendGroupEditor(store: store, account: account, friends: friends, group: nil)
        }
        .fullScreenCover(isPresented: Binding(get: { store.selectedGroupID != nil }, set: { if !$0 { store.selectedGroupID = nil } })) {
            if let group = store.selectedGroup {
                FriendGroupWorldView(store: store, account: account, friends: friends, groupID: group.id)
            }
        }
    }
}

private struct FriendGroupBubbleField: View {
    let groups: [FriendGroup]
    let open: (FriendGroup) -> Void
    @State private var physics = FriendBubblePhysics()
    @State private var dragging: String?
    @State private var dragOrigin: CGPoint?
    private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { outer in
            ScrollView {
                GeometryReader { geometry in
                    ZStack {
                        ForEach(physics.bubbles) { bubble in
                            if let group = groups.first(where: { $0.id == bubble.id }) {
                                Button { open(group) } label: {
                                    bubbleContent(group, radius: bubble.radius)
                                }
                                .buttonStyle(.plain)
                                .position(x: bubble.x, y: bubble.y)
                                .highPriorityGesture(DragGesture(minimumDistance: 9, coordinateSpace: .named("bubbles"))
                                    .onChanged { value in
                                        if dragging == nil {
                                            dragging = bubble.id
                                            dragOrigin = CGPoint(x: bubble.x, y: bubble.y)
                                        }
                                        guard let origin = dragOrigin else { return }
                                        physics.drag(id: bubble.id,
                                            x: origin.x + value.translation.width,
                                            y: origin.y + value.translation.height)
                                    }
                                    .onEnded { value in
                                        let origin = dragOrigin ?? CGPoint(x: bubble.x, y: bubble.y)
                                        physics.drag(id: bubble.id, x: origin.x + value.translation.width,
                                            y: origin.y + value.translation.height,
                                            vx: value.velocity.width, vy: value.velocity.height)
                                        dragging = nil; dragOrigin = nil
                                    })
                                .accessibilityLabel("\(group.name), \(group.memberIDs.count) members")
                                .accessibilityHint("Open the group’s rooms")
                            }
                        }
                    }
                    .coordinateSpace(name: "bubbles")
                    .onReceive(timer) { _ in
                        physics.step(width: geometry.size.width, height: geometry.size.height, dragging: dragging)
                    }
                    .onChange(of: geometry.size, initial: true) { _, size in
                        physics.arrange(ids: groups.map(\.id), width: size.width, height: size.height)
                    }
                    .onChange(of: groups.map(\.id)) { _, ids in
                        physics.arrange(ids: ids, width: geometry.size.width, height: geometry.size.height)
                    }
                }.frame(height: max(outer.size.height, CGFloat((groups.count + 1) / 2) * 190 + 28))
            }.scrollDisabled(dragging != nil)
        }
    }

    private func bubbleContent(_ group: FriendGroup, radius: Double) -> some View {
        let index = groups.firstIndex(where: { $0.id == group.id }) ?? 0
        let tint: Color = [.tasqLilac, .tasqPeach, .tasqSage][index % 3]
        return ZStack {
            WobblyCircle(wobble: 1.5).fill(tint)
                .shadow(color: Color.chartflowText.opacity(0.10), radius: 0, x: 2, y: 5)
            WobblyCircle(wobble: 1.5).stroke(Color.chartflowText, lineWidth: 1.7)
            VStack(spacing: 1) {
                HStack(spacing: -15) {
                    ForEach(Array(group.memberIDs.prefix(3).enumerated()), id: \.element) { index, _ in
                        FriendGroupSprite(avatar: .fallback)
                            .frame(width: 44, height: 55)
                            .rotationEffect(.degrees(Double(index - 1) * 9))
                    }
                }.accessibilityHidden(true)
                Text(group.name).doodleFont(21).bold().lineLimit(2).minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                Text("\(group.memberIDs.count) people").doodleFont(14)
                    .foregroundStyle(Color.chartflowSecondaryText)
            }.padding(16)
        }.frame(width: radius * 2, height: radius * 2)
    }
}

struct FriendGroupSprite: View {
    let avatar: FriendAvatarConfig
    var moving = false
    var body: some View {
        FriendAvatarView(bodyColor: avatar.bodyColor, mouth: avatar.mouth, eyes: avatar.eyes,
                         hair: avatar.hair, fur: avatar.fur, item: avatar.item,
                         hairColor: avatar.hairColor, scarfColor: avatar.scarfColor, isMoving: moving)
    }
}

private struct FriendGroupWorldView: View {
    @ObservedObject var store: FriendGroupStore
    let account: FriendHubAccount
    let friends: [FriendHubAccount]
    let groupID: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("reduceBoxMotion") private var reduceBoxMotion = false
    @AppStorage("friendAvatarBodyColor") private var bodyColor = "skin7"
    @AppStorage("friendAvatarMouth") private var mouth = "none"
    @AppStorage("friendAvatarEyes") private var eyes = "none"
    @AppStorage("friendAvatarHair") private var hair = "none"
    @AppStorage("friendAvatarFur") private var fur = "none"
    @AppStorage("friendAvatarItem") private var item = "none"
    @AppStorage("friendAvatarHairHue") private var hairHue = 0.0
    @AppStorage("friendAvatarHairSaturation") private var hairSaturation = 0.72
    @AppStorage("friendAvatarHairBrightness") private var hairBrightness = 0.86
    @AppStorage("friendAvatarScarfHue") private var scarfHue = 0.78
    @State private var settings = false
    @State private var customizer = false
    @State private var activity = false
    @State private var chat = false

    private var avatar: FriendAvatarConfig {
        FriendAvatarConfig(bodyColorRaw: bodyColor, mouthRaw: mouth, eyesRaw: eyes, hairRaw: hair,
            furRaw: fur, itemRaw: item, hairHue: hairHue, hairSaturation: hairSaturation,
            hairBrightness: hairBrightness, scarfHue: scarfHue)
    }
    private var reduced: Bool { reduceMotion || reduceBoxMotion }

    var body: some View {
        NavigationStack {
            if let group = store.selectedGroup {
                ScrollView {
                    VStack(spacing: 16) {
                        HStack {
                            DoodleSectionTitle(title: store.room.title, subtitle: store.room.subtitle)
                            DoodleBadge(title: store.connection, tint: .tasqSage)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(group.rooms) { room in
                                    Button { store.changeRoom(room) } label: {
                                        Label(room.title, systemImage: room.icon).doodleFont(17).bold()
                                            .padding(.horizontal, 14).padding(.vertical, 10)
                                            .groupCard(store.room == room ? .tasqLilac : .chartflowSurface)
                                    }.buttonStyle(.plain)
                                }
                            }.padding(2)
                        }
                        roomStage.frame(height: 360)
                        HStack(spacing: 12) {
                            ForEach(["👋", "✨", "❤️", "☕"], id: \.self) { reaction in
                                Button { store.react(reaction) } label: {
                                    Text(reaction).font(.title2).frame(maxWidth: .infinity, minHeight: 46)
                                        .groupCard(.chartflowSurface)
                                }.accessibilityLabel("React \(reaction)")
                            }
                        }
                        HStack {
                            Button { customizer = true } label: { Label("Your avatar", systemImage: "person.crop.circle") }
                            Spacer()
                            Button { settings = true } label: { Label("\(group.memberIDs.count) people", systemImage: "person.2") }
                        }.doodleFont(18).padding(.vertical, 3)
                        Button { if store.room == .lounge { chat = true } else { activity = true } } label: {
                            HStack {
                                Image(systemName: store.room.icon)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(activityTitle).doodleFont(22).bold()
                                    Text(activitySubtitle).doodleFont(16)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }.padding(18).groupCard(roomTint)
                        }.buttonStyle(.plain)
                        if !store.errorMessage.isEmpty { FriendGroupErrorBanner(message: store.errorMessage) }
                    }.padding(18)
                }
                .background(PolkaDotBackground().ignoresSafeArea())
                .foregroundStyle(Color.chartflowText)
                .navigationTitle(group.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { store.endRoom(); store.selectedGroupID = nil; dismiss() } label: {
                            Label("Hub", systemImage: "chevron.left")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { settings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("Group settings")
                    }
                }
                .sheet(isPresented: $settings) { FriendGroupEditor(store: store, account: account, friends: friends, group: group) }
                .sheet(isPresented: $chat) { FriendGroupChatPanel(store: store) }
                .sheet(isPresented: $activity) { FriendGroupActivityPanel(store: store) }
                .sheet(isPresented: $customizer) {
                    FriendAvatarCustomizerView(bodyColorRaw: $bodyColor, mouthRaw: $mouth, eyesRaw: $eyes,
                        hairRaw: $hair, furRaw: $fur, itemRaw: $item, hairHue: $hairHue,
                        hairSaturation: $hairSaturation, hairBrightness: $hairBrightness, scarfHue: $scarfHue)
                }
            }
        }
        .task(id: "\(groupID)-\(scenePhase == .active)") {
            if scenePhase == .active { await store.runRoom(groupID: groupID, avatar: avatar) }
        }
        .onChange(of: avatar) { _, value in store.updateAvatar(value) }
    }

    private var roomTint: Color { store.room == .lounge ? .tasqPeach : store.room == .quiet ? .tasqSage : .tasqLilac }
    private var activityTitle: String {
        switch store.room {
        case .lounge: return "The conversation corner"
        case .quiet: return "Focus together"
        case .arcade: return "Noughts & crosses"
        }
    }
    private var activitySubtitle: String {
        switch store.room {
        case .lounge: return store.messages.last.map { "\($0.senderName): \($0.text)" } ?? "Say hello to the group."
        case .quiet: return "A shared 25-minute moment of focus."
        case .arcade: return "Two players. Everyone can cheer."
        }
    }

    private var roomStage: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: reduced ? 1 : 1.0 / 20)) { timeline in
                let people = store.visiblePlayers(at: timeline.date)
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 28).fill(Color.chartflowSurface)
                    roomScenery(size: geometry.size)
                    ForEach(people) { player in
                        let local = player.userID == store.userID
                        let moving = player.isMoving && !reduced && timeline.date.timeIntervalSince(player.lastSeen) < 2
                        let wobble = moving ? sin(timeline.date.timeIntervalSinceReferenceDate * 12) * 4 : 0
                        VStack(spacing: 0) {
                            if timeline.date.timeIntervalSince(player.reactionAt) < 5 {
                                Text(player.reaction).font(.title2).frame(height: 28)
                            } else { Color.clear.frame(height: 28) }
                            FriendGroupSprite(avatar: player.avatar, moving: moving)
                                .frame(width: 76, height: 80).rotationEffect(.degrees(wobble))
                                .background(alignment: .bottom) {
                                    Ellipse().fill(Color.chartflowText.opacity(0.10)).frame(width: 42, height: 9).offset(y: -4)
                                }
                            Text(local ? "You" : player.name).doodleFont(14).bold()
                                .lineLimit(1).padding(.horizontal, 7).padding(.vertical, 3)
                                .background(local ? Color.tasqLilac : Color.chartflowSurface, in: Capsule())
                        }.frame(width: 95)
                            .position(x: player.x * geometry.size.width, y: player.y * geometry.size.height)
                            .animation(reduced ? nil : .linear(duration: local ? 0.065 : 0.35), value: player.x)
                            .animation(reduced ? nil : .linear(duration: local ? 0.065 : 0.35), value: player.y)
                            .allowsHitTesting(false)
                    }
                    VStack {
                        HStack {
                            Text("\(people.count) here").doodleFont(15).bold()
                            Spacer()
                            Button { chat = true } label: { Image(systemName: "bubble.left.and.bubble.right").frame(width: 44, height: 44) }
                                .accessibilityLabel("Open group chat")
                        }
                        Spacer()
                        Text("Tap the floor to wander").doodleFont(14).foregroundStyle(Color.chartflowSecondaryText)
                    }.padding(14).allowsHitTesting(true)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.chartflowText, lineWidth: 1.7))
                .contentShape(Rectangle())
                .onTapGesture { location in
                    store.move(toX: location.x / geometry.size.width, y: location.y / geometry.size.height, reducedMotion: reduced)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(store.room.title), \(people.count) people here")
                .accessibilityAction(named: "Walk left") { store.move(toX: (store.localPresence?.x ?? 0.5) - 0.15, y: store.localPresence?.y ?? 0.65, reducedMotion: reduced) }
                .accessibilityAction(named: "Walk right") { store.move(toX: (store.localPresence?.x ?? 0.5) + 0.15, y: store.localPresence?.y ?? 0.65, reducedMotion: reduced) }
                .accessibilityAction(named: "Walk up") { store.move(toX: store.localPresence?.x ?? 0.5, y: (store.localPresence?.y ?? 0.65) - 0.1, reducedMotion: reduced) }
                .accessibilityAction(named: "Walk down") { store.move(toX: store.localPresence?.x ?? 0.5, y: (store.localPresence?.y ?? 0.65) + 0.1, reducedMotion: reduced) }
            }
        }
    }

    private func roomScenery(size: CGSize) -> some View {
        ZStack {
            VStack(spacing: 0) {
                roomTint.frame(height: size.height * 0.32)
                Rectangle().fill(Color.chartflowText.opacity(0.3)).frame(height: 1)
                Color.chartflowBackground
            }
            // Doodled floorboards and a soft rug ground the characters in the room.
            Path { path in
                for row in 0..<6 {
                    let y = size.height * 0.35 + Double(row) * 45
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y + 5))
                }
            }.stroke(Color.chartflowText.opacity(0.07), lineWidth: 1)
            Ellipse().fill(roomTint.opacity(0.6)).frame(width: size.width * 0.72, height: 85).offset(y: 58)
            HStack(alignment: .top) {
                VStack(spacing: 4) {
                    Image(systemName: store.room == .quiet ? "sun.max" : "sparkles").font(.system(size: 24, weight: .light))
                    Text(store.room == .quiet ? "one thing at a time" : "glad you’re here").doodleFont(14)
                }.padding(12).groupCard(.chartflowSurface)
                Spacer()
                VStack(spacing: 0) {
                    Image(systemName: store.room == .arcade ? "gamecontroller" : "leaf").font(.system(size: 34, weight: .light))
                    RoundedRectangle(cornerRadius: 5).fill(Color.tasqPeach).frame(width: 32, height: 20)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.chartflowText, lineWidth: 1))
                }.padding(.top, 15)
            }.padding(.horizontal, 23).offset(y: -70)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct FriendGroupEditor: View {
    @ObservedObject var store: FriendGroupStore
    let account: FriendHubAccount
    let friends: [FriendHubAccount]
    let group: FriendGroup?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var members: Set<String> = []
    @State private var adminID = ""
    @State private var games = true
    @State private var focus = true
    @State private var confirmingLeave = false
    private var canEdit: Bool { group == nil || group?.adminID == account.id }
    private var allNames: [String: String] {
        if !canEdit { return group?.memberNames ?? [:] }
        var result = group?.memberNames ?? [:]
        for friend in friends { result[friend.id] = friend.displayName }
        result[account.id] = account.displayName
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name your little circle", text: $name).disabled(!canEdit)
                        .onChange(of: name) { _, value in name = String(value.prefix(32)) }
                    Text("Selected people, one admin, a space of your own.").font(.subheadline).foregroundStyle(.secondary)
                } header: { Text(group == nil ? "A new group" : "Your group") }
                Section("People · \(members.count)/20") {
                    ForEach(allNames.keys.sorted(), id: \.self) { id in
                        HStack {
                            if canEdit && id != adminID {
                                Button {
                                    if members.contains(id) { members.remove(id) }
                                    else if members.count < 20 { members.insert(id) }
                                } label: {
                                    Image(systemName: members.contains(id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(Color.chartflowText).frame(width: 35, height: 35)
                                }.buttonStyle(.plain).accessibilityLabel("Select \(allNames[id] ?? "member")")
                            } else {
                                Image(systemName: id == adminID ? "crown" : "person").frame(width: 35)
                            }
                            Text(allNames[id] ?? "Member")
                            Spacer()
                            if id == adminID { Text("Admin").font(.caption).foregroundStyle(.secondary) }
                            else if id == account.id { Text("You").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    if friends.isEmpty && group == nil {
                        Text("Add friends using Search in the hub, then select them here. You can also start your group now and add people later.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if canEdit {
                    Section("Rooms") {
                        Label("Lounge & group chat", systemImage: "bubble.left.and.bubble.right")
                        Toggle("Arcade · group games", isOn: $games)
                        Toggle("Quiet room · shared focus", isOn: $focus)
                    }
                    if group != nil {
                        Section("Admin") {
                            Picker("Group admin", selection: $adminID) {
                                ForEach(members.sorted(), id: \.self) { id in Text(allNames[id] ?? "Member").tag(id) }
                            }
                            Text("The admin manages members, room settings, and shared focus sessions. Transferring the role gives those controls to your selected member.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section { Text("Only the group admin can change members and room settings.") }
                }
                if !store.errorMessage.isEmpty { Section { Text(store.errorMessage).foregroundStyle(.red) } }
                if let group {
                    Section {
                        Button("Leave group", role: .destructive) { confirmingLeave = true }
                            .disabled(group.adminID == account.id || store.isSaving)
                        if group.adminID == account.id {
                            Text("Transfer the admin role before leaving.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Color.chartflowBackground)
            .tint(Color.chartflowText)
            .navigationTitle(group == nil ? "Create a group" : "Group settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if canEdit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(store.isSaving ? "Saving…" : group == nil ? "Create" : "Save") {
                            Task {
                                let succeeded: Bool
                                if let group {
                                    succeeded = await store.update(group: group, name: name, members: members.sorted(),
                                        names: allNames.filter { members.contains($0.key) }, adminID: adminID, games: games, focus: focus)
                                } else {
                                    succeeded = await store.create(name: name, friends: friends.filter { members.contains($0.id) }, games: games, focus: focus)
                                }
                                if succeeded { dismiss() }
                            }
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSaving)
                    }
                }
            }
            .onAppear {
                name = group?.name ?? ""
                members = Set(group?.memberIDs ?? [account.id])
                adminID = group?.adminID ?? account.id
                games = group?.gamesEnabled ?? true; focus = group?.focusEnabled ?? true
            }
            .confirmationDialog("Leave this group? An admin will need to add you again.", isPresented: $confirmingLeave, titleVisibility: .visible) {
                Button("Leave group", role: .destructive) {
                    if let group { Task { if await store.leaveGroup(group) { dismiss() } } }
                }
            }
        }
    }
}

private struct FriendGroupChatPanel: View {
    @ObservedObject var store: FriendGroupStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if store.messages.isEmpty {
                                Text("A quiet corner, for now. Say hello!").doodleFont(22).padding(.vertical, 35)
                            }
                            ForEach(store.messages) { message in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(message.senderID == store.userID ? "You" : message.senderName).bold()
                                        Spacer()
                                        Text(message.createdAt, style: .time).font(.caption)
                                    }.doodleFont(15)
                                    Text(message.text).doodleFont(19).textSelection(.enabled)
                                }.padding(14).groupCard(message.senderID == store.userID ? .tasqLilac : .chartflowSurface)
                                    .id(message.id)
                            }
                        }.padding(18)
                    }
                    .onChange(of: store.messages.last?.id, initial: true) { _, id in
                        if let id { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                if !store.errorMessage.isEmpty { FriendGroupErrorBanner(message: store.errorMessage) }
                HStack(alignment: .bottom) {
                    TextField("Say something kind…", text: $draft, axis: .vertical)
                        .lineLimit(1...4).doodleFont(19)
                        .onChange(of: draft) { _, value in draft = String(value.prefix(500)) }
                    Button {
                        let text = draft
                        Task { if await store.send(text), draft == text { draft = "" } }
                    } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)) }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSaving)
                        .accessibilityLabel("Send group message")
                }.padding(16).groupCard(.chartflowSurface).padding(.horizontal, 18).padding(.bottom, 12)
            }.foregroundStyle(Color.chartflowText).background(Color.chartflowBackground)
                .navigationTitle("Group chat").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct FriendGroupActivityPanel: View {
    @ObservedObject var store: FriendGroupStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if store.room == .quiet && store.selectedGroup?.focusEnabled == true { focusPanel }
                    else if store.room == .arcade && store.selectedGroup?.gamesEnabled == true { gamePanel }
                    else { Text("This room is currently turned off.").doodleFont(22) }
                    if !store.errorMessage.isEmpty { FriendGroupErrorBanner(message: store.errorMessage) }
                }.padding(24)
            }.background(Color.chartflowBackground).foregroundStyle(Color.chartflowText)
                .navigationTitle(store.room == .quiet ? "Focus together" : "Noughts & crosses")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var focusPanel: some View {
        VStack(spacing: 24) {
            DoodleSun()
            Text("A little company helps.").doodleFont(28).bold()
            Text("Pick one thing to work on. Everyone shares the same timer, even when they arrive a little later.")
                .doodleFont(19).multilineTextAlignment(.center)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let end = store.focusEndsAt, end > context.date {
                    Text(end, style: .timer).font(.system(size: 60, weight: .light, design: .rounded)).monospacedDigit()
                } else {
                    Text(store.focusEndsAt == nil ? "25:00" : "Time for a stretch!").doodleFont(44)
                }
            }
            if store.isAdmin {
                Button { Task { await store.setFocus(minutes: 25) } } label: {
                    Text(store.focusEndsAt == nil ? "Start together" : "Start a fresh session")
                }.buttonStyle(DoodleButtonStyle(tint: .tasqSage)).disabled(store.isSaving)
                if store.focusEndsAt != nil {
                    Button("End session") { Task { await store.setFocus(minutes: nil) } }.disabled(store.isSaving)
                }
            } else { Text("Your group admin starts the shared timer.").doodleFont(17) }
        }
    }

    private var gamePanel: some View {
        VStack(spacing: 20) {
            Text(gameStatus).doodleFont(27).bold().multilineTextAlignment(.center)
            HStack {
                Text("X · \(name(store.game.xID))")
                Spacer()
                Text("O · \(name(store.game.oID))")
            }.doodleFont(18)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(0..<9) { index in
                    Button { Task { await store.play(index) } } label: {
                        Text(store.game.board.count == 9 ? store.game.board[index] : "")
                            .font(.system(size: 48, weight: .light, design: .rounded))
                            .frame(maxWidth: .infinity).frame(height: 82).groupCard(.tasqLilac)
                    }.buttonStyle(.plain)
                        .disabled(store.isSaving || store.game.currentPlayerID != store.userID || store.game.winner != nil || store.game.oID.isEmpty || store.game.board.count != 9 || !store.game.board[index].isEmpty)
                        .accessibilityLabel("Row \(index / 3 + 1), column \(index % 3 + 1), \(store.game.board.count == 9 && !store.game.board[index].isEmpty ? store.game.board[index] : "empty")")
                }
            }
            if ![store.game.xID, store.game.oID].contains(store.userID) && (store.game.xID.isEmpty || store.game.oID.isEmpty) {
                Button("Join the game") { Task { await store.joinGame() } }
                    .buttonStyle(DoodleButtonStyle(tint: .tasqPeach)).disabled(store.isSaving)
            }
            if store.isAdmin || (store.game.winner != nil && [store.game.xID, store.game.oID].contains(store.userID)) {
                Button("New round") { Task { await store.resetGame() } }.disabled(store.isSaving || store.game.xID.isEmpty)
            }
            Text("Two friends play; the whole room can watch. The admin can reset an abandoned game.")
                .doodleFont(17).multilineTextAlignment(.center).foregroundStyle(Color.chartflowSecondaryText)
        }
    }
    private func name(_ id: String) -> String { id.isEmpty ? "Open seat" : id == store.userID ? "You" : store.selectedGroup?.memberNames[id] ?? "Member" }
    private var gameStatus: String {
        if let winner = store.game.winner { return winner == "Draw" ? "A lovely little draw." : "\(name(winner == "X" ? store.game.xID : store.game.oID)) won!" }
        if store.game.xID.isEmpty || store.game.oID.isEmpty { return "Pull up a seat." }
        return store.game.currentPlayerID == store.userID ? "Your turn · \(store.game.turn)" : "\(name(store.game.currentPlayerID))’s turn"
    }
}

private struct FriendGroupErrorBanner: View {
    let message: String
    var body: some View {
        Text(message).doodleFont(16).foregroundStyle(Color.chartflowText)
            .padding(12).frame(maxWidth: .infinity).groupCard(.tasqPeach).padding(.horizontal, 18)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

private extension View {
    func groupCard(_ tint: Color) -> some View {
        chartflowBox(cornerRadius: 16, wobble: 1, fillColor: tint, strokeColor: .chartflowText.opacity(0.7), lineWidth: 1.3)
    }
}

#if DEBUG
/// Local visual fixture; launched explicitly for simulator QA, never in release builds.
struct FriendGroupVisualCheck: View {
    private let account = FriendHubAccount(id: "preview-you", username: "you", displayName: "You",
        profileIconName: "person.crop.circle", profileColorRaw: "blue", bio: "", status: "", friendIDs: [])
    var body: some View {
        NavigationStack {
            FriendGroupHubView(account: account, friends: [])
                .padding(.top, 12)
                .background(PolkaDotBackground().ignoresSafeArea())
                .navigationTitle("Friend Hub")
                .navigationBarTitleDisplayMode(.inline)
        }
        // Reserve the surrounding workspace navigation space as in the embedded app.
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 16) {
                Text("Tasq").doodleFont(30).frame(maxWidth: .infinity, alignment: .leading)
                Text("Hub     Search     Friends     Notifs     Profile").doodleFont(16)
            }.padding(20).background(Color.chartflowBackground)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Text("Today"); Spacer(); Text("Routines"); Spacer(); Text("Friends")
            }.doodleFont(18).padding(.horizontal, 30).frame(height: 86).background(Color.chartflowBackground)
        }
    }
}
#endif
