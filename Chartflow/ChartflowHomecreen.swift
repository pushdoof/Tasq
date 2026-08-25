import SwiftUI
internal import Combine

struct MindflowHomeScreen: View {
    @Binding var charts: [Chart]
    @AppStorage("defaultZoom") private var defaultZoom: Double = 1.3
    @State private var showSettingsSheet = false
    @State private var showFriendHub = false

    var body: some View {
        NavigationStack {
            ZStack {
                PolkaDotBackground()
                    .ignoresSafeArea()

                MindflowHomeDecorations()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(0)

                MindflowStatusBarBacking()
                    .allowsHitTesting(false)
                    .zIndex(0.5)

                VStack(spacing: 18) {
                    Spacer(minLength: 32)

                    Text("Mindflow")
                        .font(.custom("ChartflowHand-Regular", size: 48))
                        .fontWeight(.black)
                        .foregroundStyle(Color.chartflowText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.chartflowSurface.opacity(0.94))
                                .shadow(color: Color.chartflowBackground.opacity(0.9), radius: 8, x: 0, y: 0)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.chartflowText.opacity(0.18), lineWidth: 1)
                        }

                    VStack(spacing: 14) {
                        NavigationLink {
                            HomeScreen(charts: $charts)
                        } label: {
                            MindflowHomeButton(title: "Chartflow", systemImage: "list.bullet.rectangle.fill")
                        }
                        .buttonStyle(.plain)

                        Button {
                            showFriendHub = true
                        } label: {
                            MindflowHomeButton(title: "Friend Hub", systemImage: "person.2.fill")
                        }
                        .buttonStyle(.plain)

                        Button {
                            showSettingsSheet = true
                        } label: {
                            MindflowHomeButton(title: "Settings", systemImage: "gearshape.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 520)

                    Spacer(minLength: 32)
                }
                .zIndex(1)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(defaultZoom: $defaultZoom)
            }
            .sheet(isPresented: $showFriendHub) {
                FriendHubView()
            }
        }
    }
}

struct MindflowStatusBarBacking: View {
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.chartflowSurface.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.chartflowText.opacity(0.22), lineWidth: 1)
                }
                .frame(width: 86, height: 30)

            Spacer()

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.chartflowSurface.opacity(0.9))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.chartflowText.opacity(0.22), lineWidth: 1)
                }
                .frame(width: 118, height: 30)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }
}

struct MindflowHomeDecorations: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let narrowSide = min(size.width, size.height)
            let topArtWidth = min(narrowSide * 0.5, 250)
            let sideArtWidth = min(narrowSide * 0.56, 280)
            let bottomArtWidth = min(narrowSide * 0.5, 250)

            ZStack {
                Image("MindflowRainbowLines")
                    .resizable()
                    .scaledToFit()
                    .blendMode(.multiply)
                    .frame(width: sideArtWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Image("MindflowRainbowCloud")
                    .resizable()
                    .scaledToFit()
                    .blendMode(.multiply)
                    .frame(width: topArtWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                Image("MindflowSwooshStars")
                    .resizable()
                    .scaledToFit()
                    .blendMode(.multiply)
                    .frame(width: sideArtWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                Image("MindflowYouGotThis")
                    .resizable()
                    .scaledToFit()
                    .blendMode(.multiply)
                    .frame(width: bottomArtWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }
}

struct MindflowHomeButton: View {
    let title: String
    let systemImage: String
    @AppStorage("boldText") private var boldText = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 32)

            Text(title)
                .font(.custom("ChartflowHand-Regular", size: 28))
                .fontWeight(boldText ? .black : .bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold))
        }
        .foregroundStyle(Color.chartflowText)
        .frame(maxWidth: .infinity, minHeight: 78)
        .padding(.horizontal, 22)
        .chartflowBox(cornerRadius: 18, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
    }
}

struct HomeScreen: View {
    @Binding var charts: [Chart]
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultZoom") private var defaultZoom: Double = 1.3
    @State private var isDeleteMode = false
    @State private var showDeleteConfirmation = false
    @State private var chartToDelete: Chart? = nil
    @State private var showOnboardingSheet = false

    let cardHeight: CGFloat = 72
    let cardSpacing: CGFloat = 16

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                ZStack(alignment: .bottomTrailing) {
                    PolkaDotBackground()
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.chartflowText)
                            }
                            .padding(.leading, 20)
                            .accessibilityLabel("Back to Mindflow")

                            Spacer(minLength: 0)
                            Text("Chartflow")
                                .font(.custom("ChartflowHand-Regular", size: 36))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.chartflowText)
                            Spacer(minLength: 0)
                            Button {
                                showOnboardingSheet = true
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.chartflowText)
                            }
                            .padding(.trailing, 20)
                            .accessibilityLabel("Help")
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                        ScrollView {
                            VStack(spacing: cardSpacing) {
                                ForEach(Array(charts.enumerated()), id: \.element.id) { index, chart in
                                    ZStack(alignment: .topTrailing) {
                                        if isDeleteMode {
                                            Button {
                                                chartToDelete = chart
                                                showDeleteConfirmation = true
                                            } label: {
                                                RoutineCardView(chart: chart)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                                                    )
                                            }
                                            .buttonStyle(.plain)

                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundStyle(.red)
                                                .background(Color.chartflowSurface)
                                                .clipShape(Circle())
                                                .offset(x: 8, y: -8)
                                        } else {
                                            NavigationLink {
                                                ChartEditorView(chart: $charts[index])
                                                    .onAppear { }
                                            } label: {
                                                RoutineCardView(chart: chart)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .frame(height: cardHeight)
                                    .animation(.easeInOut(duration: 0.2), value: isDeleteMode)
                                }

                                if charts.count < 5 {
                                    Button {
                                        charts.append(Chart.blank())
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 36))
                                            .foregroundStyle(Color.chartflowText)
                                    }
                                    .padding(.top, 8)
                                }

                                Text("v1.1 by Pushya Dutt")
                                    .font(.custom("ChartflowHand-Regular", size: 14))
                                    .foregroundStyle(Color.gray)
                                    .padding(.top, 12)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 100)
                        }
                    }

                    Button {
                        withAnimation {
                            isDeleteMode.toggle()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isDeleteMode ? Color.red : Color.chartflowSurface)
                                .frame(width: 56, height: 56)
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                            Image(systemName: isDeleteMode ? "xmark" : "trash")
                                .font(.system(size: 22))
                                .foregroundStyle(isDeleteMode ? Color.white : Color.red)
                        }
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 40)
                }
                .alert("Delete Routine?", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {
                        chartToDelete = nil
                    }
                    Button("Delete", role: .destructive) {
                        if let chart = chartToDelete {
                            withAnimation {
                                charts.removeAll { $0.id == chart.id }
                            }
                        }
                        chartToDelete = nil
                        isDeleteMode = false
                    }
                } message: {
                    Text("This will permanently delete \"\(chartToDelete?.name ?? "this routine")\". This cannot be undone.")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showOnboardingSheet) {
                OnboardingView(
                    hasSeenOnboarding: .constant(true),
                    defaultZoom: $defaultZoom,
                    showsSkipButton: false
                ) {
                    showOnboardingSheet = false
                }
            }
        }
    }
}

enum FriendAvatarBodyColor: String, CaseIterable, Identifiable {
    case skin1
    case skin2
    case skin3
    case skin4
    case skin5
    case skin6
    case skin7
    case skin8

    var id: String { rawValue }

    var title: String {
        "Skin \(assetNumber)"
    }

    var imageName: String {
        String(format: "FriendAsset%02d", assetNumber)
    }

    private var assetNumber: Int {
        switch self {
        case .skin1: return 1
        case .skin2: return 2
        case .skin3: return 3
        case .skin4: return 4
        case .skin5: return 5
        case .skin6: return 6
        case .skin7: return 7
        case .skin8: return 8
        }
    }
}

enum FriendAvatarMouth: String, CaseIterable, Identifiable {
    case none
    case mouth9
    case mouth10
    case mouth11
    case mouth12
    case mouth13
    case susie

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .mouth9: return "Mouth 1"
        case .mouth10: return "Mouth 2"
        case .mouth11: return "Mouth 3"
        case .mouth12: return "Mouth 4"
        case .mouth13: return "Mouth 5"
        case .susie: return "Susie Mouth"
        }
    }

    var imageNames: [String] {
        switch self {
        case .none: return []
        case .mouth9: return ["FriendAsset09"]
        case .mouth10: return ["FriendAsset10"]
        case .mouth11: return ["FriendAsset11"]
        case .mouth12: return ["FriendAsset12"]
        case .mouth13: return ["FriendAsset13"]
        case .susie: return ["FriendAsset29", "FriendAsset30"]
        }
    }
}

enum FriendAvatarEyes: String, CaseIterable, Identifiable {
    case none
    case eyes28
    case eyes31

    static let allCases: [FriendAvatarEyes] = [.none, .eyes31, .eyes28]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .eyes31: return "Eyes 1"
        case .eyes28: return "Eyes 3"
        }
    }

    var imageName: String? {
        switch self {
        case .none: return nil
        case .eyes28: return "FriendAsset28"
        case .eyes31: return "FriendAsset31"
        }
    }
}

enum FriendAvatarHair: String, CaseIterable, Identifiable {
    case none
    case hair16
    case hair19

    static let allCases: [FriendAvatarHair] = [.none, .hair16, .hair19]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .hair16: return "Hair 1"
        case .hair19: return "Hair 2"
        }
    }

    var imageNames: [String] {
        switch self {
        case .none: return []
        case .hair16: return ["FriendAsset16", "FriendAsset18"]
        case .hair19: return ["FriendAsset19", "FriendAsset21"]
        }
    }

    var fillImageName: String? {
        switch self {
        case .none: return nil
        case .hair16: return "FriendAsset16"
        case .hair19: return "FriendAsset19"
        }
    }

    var outlineImageName: String? {
        switch self {
        case .none: return nil
        case .hair16: return "FriendAsset18"
        case .hair19: return "FriendAsset21"
        }
    }

    var canStackWithFur: Bool {
        false
    }
}

enum FriendAvatarFur: String, CaseIterable, Identifiable {
    case none
    case fur14

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .fur14: return "Fur"
        }
    }

    var imageNames: [String] {
        switch self {
        case .none: return []
        case .fur14: return ["FriendAsset22", "FriendAsset25"]
        }
    }

    var fillImageName: String? {
        switch self {
        case .none: return nil
        case .fur14: return "FriendAsset22"
        }
    }

    var outlineImageName: String? {
        switch self {
        case .none: return nil
        case .fur14: return "FriendAsset25"
        }
    }
}

struct FriendScarfPresetColor: Identifiable {
    let title: String
    let hue: Double
    let saturation: Double
    let brightness: Double
    let color: Color

    init(title: String, hue: Double, saturation: Double = 0.68, brightness: Double = 0.82, color: Color) {
        self.title = title
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.color = color
    }

    var id: String { title }
}

enum FriendAvatarItem: String, CaseIterable, Identifiable {
    case none
    case scarf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .scarf: return "Scarf"
        }
    }

    var imageNames: [String] {
        switch self {
        case .none: return []
        case .scarf: return ["FriendAsset26", "FriendAsset27"]
        }
    }

    var fillImageName: String? {
        switch self {
        case .none: return nil
        case .scarf: return "FriendAsset26"
        }
    }

    var outlineImageName: String? {
        switch self {
        case .none: return nil
        case .scarf: return "FriendAsset27"
        }
    }
}

struct FriendHubView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var multiplayerStore = FriendHubMultiplayerStore()
    @AppStorage("friendAvatarX") private var avatarX = 0.5
    @AppStorage("friendAvatarY") private var avatarY = 0.58
    @AppStorage("friendAvatarBodyColor") private var bodyColorRaw = FriendAvatarBodyColor.skin7.rawValue
    @AppStorage("friendAvatarMouth") private var mouthRaw = FriendAvatarMouth.none.rawValue
    @AppStorage("friendAvatarEyes") private var eyesRaw = FriendAvatarEyes.none.rawValue
    @AppStorage("friendAvatarHair") private var hairRaw = FriendAvatarHair.none.rawValue
    @AppStorage("friendAvatarFur") private var furRaw = FriendAvatarFur.none.rawValue
    @AppStorage("friendAvatarItem") private var itemRaw = FriendAvatarItem.none.rawValue
    @AppStorage("friendAvatarHairHue") private var hairHue = 0.0
    @AppStorage("friendAvatarHairSaturation") private var hairSaturation = 0.72
    @AppStorage("friendAvatarHairBrightness") private var hairBrightness = 0.86
    @AppStorage("friendAvatarScarfHue") private var scarfHue = 0.78
    @State private var showCustomizer = false
    @State private var isDragging = false

    private var bodyColor: FriendAvatarBodyColor {
        FriendAvatarBodyColor(rawValue: bodyColorRaw) ?? .skin7
    }

    private var mouth: FriendAvatarMouth {
        FriendAvatarMouth(rawValue: mouthRaw) ?? .none
    }

    private var eyes: FriendAvatarEyes {
        FriendAvatarEyes(rawValue: eyesRaw) ?? .none
    }

    private var hair: FriendAvatarHair {
        FriendAvatarHair(rawValue: hairRaw) ?? .none
    }

    private var fur: FriendAvatarFur {
        FriendAvatarFur(rawValue: furRaw) ?? .none
    }

    private var item: FriendAvatarItem {
        FriendAvatarItem(rawValue: itemRaw) ?? .none
    }

    private var scarfColor: Color {
        Color(hue: scarfHue, saturation: 0.68, brightness: 0.82)
    }

    private var hairColor: Color {
        Color(hue: hairHue, saturation: hairSaturation, brightness: hairBrightness)
    }

    private var localAvatarConfig: FriendAvatarConfig {
        FriendAvatarConfig(
            bodyColorRaw: bodyColorRaw,
            mouthRaw: mouthRaw,
            eyesRaw: eyesRaw,
            hairRaw: hairRaw,
            furRaw: furRaw,
            itemRaw: itemRaw,
            hairHue: hairHue,
            hairSaturation: hairSaturation,
            hairBrightness: hairBrightness,
            scarfHue: scarfHue
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GeometryReader { proxy in
                    let size = proxy.size
                    let avatarSize = min(size.width * 0.32, 118)
                    ZStack {
                        ClubPenguinRoomBackground()

                        TimelineView(.animation(minimumInterval: 0.2)) { timeline in
                            ForEach(multiplayerStore.players) { player in
                                let isLocalPlayer = player.id == multiplayerStore.localPlayerID
                                FriendHubPlayerAvatar(
                                    player: player,
                                    avatarSize: avatarSize,
                                    point: CGPoint(x: player.x * size.width, y: player.y * size.height),
                                    animationTime: timeline.date.timeIntervalSinceReferenceDate,
                                    isLocalPlayer: isLocalPlayer,
                                    isDragging: isLocalPlayer && isDragging,
                                    openCustomizer: {
                                        showCustomizer = true
                                    },
                                    dragChanged: { point in
                                        isDragging = true
                                        updateAvatarPosition(point, in: size, isMoving: true)
                                    },
                                    dragEnded: { point in
                                        updateAvatarPosition(point, in: size, isMoving: false)
                                        isDragging = false
                                    }
                                )
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.chartflowText, lineWidth: 2)
                    )
                }
                .frame(minHeight: 420)
                .padding(.horizontal, 18)

                VStack(spacing: 10) {
                    Text("\(multiplayerStore.connectionStatus) • \(multiplayerStore.players.count) online")
                        .font(.custom("ChartflowHand-Regular", size: 15))
                        .foregroundStyle(Color.chartflowSecondaryText)

                    Button {
                        showCustomizer = true
                    } label: {
                        Label("Change Avatar", systemImage: "paintpalette.fill")
                            .font(.custom("ChartflowHand-Regular", size: 18))
                            .foregroundStyle(Color.chartflowBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.chartflowText)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }
            .background(PolkaDotBackground().ignoresSafeArea())
            .task {
                multiplayerStore.join(name: "You", avatar: localAvatarConfig, x: avatarX, y: avatarY)
            }
            .onDisappear {
                multiplayerStore.leave()
            }
            .onChange(of: localAvatarConfig) { _, newConfig in
                multiplayerStore.updateLocalAvatar(newConfig)
            }
            .navigationTitle("Friend Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $showCustomizer) {
                FriendAvatarCustomizerView(
                    bodyColorRaw: $bodyColorRaw,
                    mouthRaw: $mouthRaw,
                    eyesRaw: $eyesRaw,
                    hairRaw: $hairRaw,
                    furRaw: $furRaw,
                    itemRaw: $itemRaw,
                    hairHue: $hairHue,
                    hairSaturation: $hairSaturation,
                    hairBrightness: $hairBrightness,
                    scarfHue: $scarfHue
                )
            }
        }
    }

    private func updateAvatarPosition(_ point: CGPoint, in size: CGSize, isMoving: Bool) {
        let horizontalPadding = 48.0
        let verticalPadding = 70.0
        let x = min(max(point.x, horizontalPadding), max(horizontalPadding, size.width - horizontalPadding))
        let y = min(max(point.y, verticalPadding), max(verticalPadding, size.height - verticalPadding))
        avatarX = x / max(size.width, 1)
        avatarY = y / max(size.height, 1)
        multiplayerStore.updateLocalPosition(x: avatarX, y: avatarY, isMoving: isMoving)
    }
}

struct FriendHubPlayerAvatar: View {
    let player: FriendHubPlayer
    let avatarSize: Double
    let point: CGPoint
    let animationTime: TimeInterval
    let isLocalPlayer: Bool
    let isDragging: Bool
    let openCustomizer: () -> Void
    let dragChanged: (CGPoint) -> Void
    let dragEnded: (CGPoint) -> Void

    var body: some View {
        if isLocalPlayer {
            avatarContent
                .contentShape(Rectangle())
                .onTapGesture(perform: openCustomizer)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragChanged(value.location)
                        }
                        .onEnded { value in
                            dragEnded(value.location)
                        }
                )
        } else {
            avatarContent
                .allowsHitTesting(false)
        }
    }

    private var avatarContent: some View {
        let isMoving = isDragging || player.isMoving
        let waddle = isMoving ? sin(animationTime * 5.0) * 5 : sin(animationTime * 1.8) * 2
        let bob = isMoving ? abs(sin(animationTime * 5.0)) * 5 : abs(sin(animationTime * 1.8)) * 2

        return VStack(spacing: 3) {
            Text(player.name)
                .font(.custom("ChartflowHand-Regular", size: 18))
                .foregroundStyle(Color.chartflowText)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .chartflowBox(cornerRadius: 10, wobble: 1.5, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.5)

            FriendAvatarView(
                bodyColor: player.avatar.bodyColor,
                mouth: player.avatar.mouth,
                eyes: player.avatar.eyes,
                hair: player.avatar.hair,
                fur: player.avatar.fur,
                item: player.avatar.item,
                hairColor: player.avatar.hairColor,
                scarfColor: player.avatar.scarfColor,
                isMoving: isMoving
            )
            .frame(width: avatarSize, height: avatarSize * 1.25)
            .rotationEffect(.degrees(waddle))
            .offset(y: -bob)
        }
        .position(point)
    }
}

struct FriendAvatarCustomizerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bodyColorRaw: String
    @Binding var mouthRaw: String
    @Binding var eyesRaw: String
    @Binding var hairRaw: String
    @Binding var furRaw: String
    @Binding var itemRaw: String
    @Binding var hairHue: Double
    @Binding var hairSaturation: Double
    @Binding var hairBrightness: Double
    @Binding var scarfHue: Double

    private var bodyColor: FriendAvatarBodyColor {
        FriendAvatarBodyColor(rawValue: bodyColorRaw) ?? .skin7
    }

    private var mouth: FriendAvatarMouth {
        FriendAvatarMouth(rawValue: mouthRaw) ?? .none
    }

    private var eyes: FriendAvatarEyes {
        FriendAvatarEyes(rawValue: eyesRaw) ?? .none
    }

    private var hair: FriendAvatarHair {
        FriendAvatarHair(rawValue: hairRaw) ?? .none
    }

    private var fur: FriendAvatarFur {
        FriendAvatarFur(rawValue: furRaw) ?? .none
    }

    private var item: FriendAvatarItem {
        FriendAvatarItem(rawValue: itemRaw) ?? .none
    }

    private var scarfColor: Color {
        Color(hue: scarfHue, saturation: 0.68, brightness: 0.82)
    }

    private var hairColor: Color {
        Color(hue: hairHue, saturation: hairSaturation, brightness: hairBrightness)
    }

    private let scarfPresetColors = [
        FriendScarfPresetColor(title: "Ralsei Green", hue: 0.36, color: Color(red: 0.48, green: 0.72, blue: 0.46))
    ]

    private let hairPresetColors = [
        FriendScarfPresetColor(title: "Black", hue: 0.08, saturation: 0.35, brightness: 0.10, color: Color(red: 0.08, green: 0.06, blue: 0.05)),
        FriendScarfPresetColor(title: "Brown", hue: 0.08, saturation: 0.64, brightness: 0.34, color: Color(red: 0.34, green: 0.20, blue: 0.11)),
        FriendScarfPresetColor(title: "Blonde", hue: 0.12, saturation: 0.48, brightness: 0.82, color: Color(red: 0.82, green: 0.66, blue: 0.34)),
        FriendScarfPresetColor(title: "Ginger", hue: 0.06, saturation: 0.78, brightness: 0.62, color: Color(red: 0.68, green: 0.28, blue: 0.10)),
        FriendScarfPresetColor(title: "White", hue: 0.10, saturation: 0.04, brightness: 0.94, color: Color(red: 0.92, green: 0.90, blue: 0.86)),
        FriendScarfPresetColor(title: "Kris Blue", hue: 0.61, saturation: 0.57, brightness: 0.42, color: Color(red: 0.18, green: 0.24, blue: 0.42)),
        FriendScarfPresetColor(title: "Susie Purple", hue: 0.80, saturation: 0.57, brightness: 0.35, color: Color(red: 0.31, green: 0.15, blue: 0.35))
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avatar Shop")
                                .font(.custom("ChartflowHand-Regular", size: 28))
                                .foregroundStyle(Color.chartflowText)
                            Text("Your look")
                                .font(.custom("ChartflowHand-Regular", size: 15))
                                .foregroundStyle(Color.chartflowSecondaryText)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.47, green: 0.36, blue: 0.82),
                                        Color(red: 0.24, green: 0.65, blue: 0.88)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(spacing: 8) {
                            FriendAvatarView(
                                bodyColor: bodyColor,
                                mouth: mouth,
                                eyes: eyes,
                                hair: hair,
                                fur: fur,
                                item: item,
                                hairColor: hairColor,
                                scarfColor: scarfColor,
                                isMoving: false
                            )
                            .frame(width: 150, height: 150)

                            Button {
                                dismiss()
                            } label: {
                                Label("Save", systemImage: "checkmark")
                                    .font(.custom("ChartflowHand-Regular", size: 16))
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.75))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(16)
                    }
                    .frame(height: 230)
                    .padding(.horizontal, 18)
                }
                .padding(.bottom, 12)
                .background(Color.chartflowSurface)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Skin")
                                .font(.custom("ChartflowHand-Regular", size: 22))
                                .foregroundStyle(Color.chartflowText)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                                ForEach(FriendAvatarBodyColor.allCases) { color in
                                    FriendShopItemCard(
                                        title: color.title,
                                        isSelected: bodyColorRaw == color.rawValue
                                    ) {
                                        FriendAvatarLayer(imageName: color.imageName)
                                    } action: {
                                        bodyColorRaw = color.rawValue
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Eyes")
                                .font(.custom("ChartflowHand-Regular", size: 22))
                                .foregroundStyle(Color.chartflowText)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                                ForEach(FriendAvatarEyes.allCases) { eyes in
                                    FriendShopItemCard(
                                        title: eyes.title,
                                        isSelected: eyesRaw == eyes.rawValue
                                    ) {
                                        FriendEyesPreview(eyes: eyes)
                                    } action: {
                                        eyesRaw = eyes.rawValue
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Hair")
                                .font(.custom("ChartflowHand-Regular", size: 22))
                                .foregroundStyle(Color.chartflowText)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                                ForEach(FriendAvatarHair.allCases) { hair in
                                    FriendShopItemCard(
                                        title: hair.title,
                                        isSelected: hairRaw == hair.rawValue
                                    ) {
                                        FriendHairPreview(hair: hair, hairColor: hairColor)
                                    } action: {
                                        hairRaw = hair.rawValue
                                        furRaw = FriendAvatarFur.none.rawValue
                                    }
                                }
                            }

                            if hair != .none {
                                ScarfColorTool(
                                    title: "Hair Color",
                                    hue: $hairHue,
                                    saturation: $hairSaturation,
                                    brightness: $hairBrightness,
                                    currentColor: hairColor,
                                    presetColors: hairPresetColors
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Mouth")
                                .font(.custom("ChartflowHand-Regular", size: 22))
                                .foregroundStyle(Color.chartflowText)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                                ForEach(FriendAvatarMouth.allCases) { mouth in
                                    FriendShopItemCard(
                                        title: mouth.title,
                                        isSelected: mouthRaw == mouth.rawValue
                                    ) {
                                        FriendMouthPreview(mouth: mouth)
                                    } action: {
                                        mouthRaw = mouth.rawValue
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Items")
                                .font(.custom("ChartflowHand-Regular", size: 22))
                                .foregroundStyle(Color.chartflowText)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                                ForEach(FriendAvatarItem.allCases) { item in
                                    FriendShopItemCard(
                                        title: item.title,
                                        isSelected: itemRaw == item.rawValue
                                    ) {
                                        FriendItemPreview(item: item, scarfColor: scarfColor)
                                    } action: {
                                        itemRaw = item.rawValue
                                    }
                                }
                            }

                            if item == .scarf {
                                ScarfColorTool(
                                    title: "Scarf Color",
                                    hue: $scarfHue,
                                    currentColor: scarfColor,
                                    presetColors: scarfPresetColors
                                )
                            }
                        }
                    }
                    .padding(16)
                }
                .background(PolkaDotBackground())
            }
            .navigationTitle("Your Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ClubPenguinRoomBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.92, blue: 0.98),
                    Color(red: 0.93, green: 0.97, blue: 0.99)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()
                WobblyRectangle(cornerRadius: 36, wobble: 5)
                    .fill(Color.white.opacity(0.9))
                    .frame(height: 130)
                    .overlay(
                        WobblyRectangle(cornerRadius: 36, wobble: 5)
                            .stroke(Color.chartflowText.opacity(0.2), lineWidth: 2)
                    )
            }

            Canvas { context, size in
                let path = Path { path in
                    path.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.78))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.88, y: size.height * 0.76),
                        control1: CGPoint(x: size.width * 0.34, y: size.height * 0.68),
                        control2: CGPoint(x: size.width * 0.62, y: size.height * 0.88)
                    )
                }
                context.stroke(path, with: .color(Color.chartflowText.opacity(0.18)), lineWidth: 3)
            }
        }
    }
}

struct FriendAvatarView: View {
    let bodyColor: FriendAvatarBodyColor
    let mouth: FriendAvatarMouth
    let eyes: FriendAvatarEyes
    let hair: FriendAvatarHair
    let fur: FriendAvatarFur
    let item: FriendAvatarItem
    let hairColor: Color
    let scarfColor: Color
    let isMoving: Bool

    var body: some View {
        ZStack {
            FriendAvatarLayer(imageName: bodyColor.imageName)
            FriendHairLayers(hair: hair, hairColor: hairColor)
            FriendItemLayers(item: item, scarfColor: scarfColor)
            ForEach(mouth.imageNames, id: \.self) { mouthImageName in
                FriendAvatarLayer(imageName: mouthImageName)
            }
            if let eyesImageName = eyes.imageName {
                FriendAvatarLayer(imageName: eyesImageName)
            }
        }
        .scaleEffect(x: isMoving ? 1.03 : 1, y: isMoving ? 0.98 : 1, anchor: .bottom)
        .aspectRatio(1, contentMode: .fit)
    }
}

struct FriendHairLayers: View {
    let hair: FriendAvatarHair
    let hairColor: Color

    @ViewBuilder
    var body: some View {
        if let fillImageName = hair.fillImageName {
            FriendAvatarLayer(imageName: fillImageName, tintColor: hairColor)
        }
        if let outlineImageName = hair.outlineImageName {
            FriendAvatarLayer(imageName: outlineImageName)
        }
    }
}

struct FriendFurLayers: View {
    let fur: FriendAvatarFur

    @ViewBuilder
    var body: some View {
        ForEach(fur.imageNames, id: \.self) { imageName in
            FriendAvatarLayer(imageName: imageName)
        }
    }
}

struct FriendItemLayers: View {
    let item: FriendAvatarItem
    let scarfColor: Color

    @ViewBuilder
    var body: some View {
        if item == .scarf {
            if let fillImageName = item.fillImageName {
                FriendAvatarLayer(imageName: fillImageName, tintColor: scarfColor)
            }
            if let outlineImageName = item.outlineImageName {
                FriendAvatarLayer(imageName: outlineImageName)
            }
        }
    }
}

struct FriendHairPreview: View {
    let hair: FriendAvatarHair
    let hairColor: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.chartflowSecondaryText.opacity(0.12))

            if hair.imageNames.isEmpty {
                Image(systemName: "nosign")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.chartflowSecondaryText)
            } else {
                FriendHairLayers(hair: hair, hairColor: hairColor)
                    .padding(4)
            }
        }
        .frame(width: 44, height: 44)
    }
}

struct FriendFurPreview: View {
    let fur: FriendAvatarFur

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.chartflowSecondaryText.opacity(0.12))

            if fur.imageNames.isEmpty {
                Image(systemName: "nosign")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.chartflowSecondaryText)
            } else {
                FriendFurLayers(fur: fur)
                    .padding(4)
            }
        }
        .frame(width: 44, height: 44)
    }
}

struct FriendMouthPreview: View {
    let mouth: FriendAvatarMouth

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.chartflowSecondaryText.opacity(0.12))

            if mouth.imageNames.isEmpty {
                Image(systemName: "nosign")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.chartflowSecondaryText)
            } else {
                ForEach(mouth.imageNames, id: \.self) { imageName in
                    FriendAvatarLayer(imageName: imageName)
                        .padding(4)
                }
            }
        }
        .frame(width: 44, height: 44)
    }
}

struct FriendEyesPreview: View {
    let eyes: FriendAvatarEyes

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.chartflowSecondaryText.opacity(0.12))

            if let imageName = eyes.imageName {
                FriendAvatarLayer(imageName: imageName)
                    .padding(4)
            } else {
                Image(systemName: "nosign")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.chartflowSecondaryText)
            }
        }
        .frame(width: 44, height: 44)
    }
}

struct FriendItemPreview: View {
    let item: FriendAvatarItem
    let scarfColor: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.chartflowSecondaryText.opacity(0.12))

            if item.imageNames.isEmpty {
                Image(systemName: "nosign")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.chartflowSecondaryText)
            } else {
                FriendItemLayers(item: item, scarfColor: scarfColor)
                    .padding(4)
            }
        }
        .frame(width: 44, height: 44)
    }
}

struct ScarfColorTool: View {
    let title: String
    @Binding var hue: Double
    var saturation: Binding<Double>? = nil
    var brightness: Binding<Double>? = nil
    let currentColor: Color
    let presetColors: [FriendScarfPresetColor]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.custom("ChartflowHand-Regular", size: 18))
                    .foregroundStyle(Color.chartflowText)

                Spacer()

                Circle()
                    .fill(currentColor)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.chartflowText, lineWidth: 1.5))
            }

            Slider(value: $hue, in: 0...1)
                .tint(currentColor)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                ForEach(presetColors) { preset in
                    Button {
                        hue = preset.hue
                        saturation?.wrappedValue = preset.saturation
                        brightness?.wrappedValue = preset.brightness
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(Color.chartflowText.opacity(0.45), lineWidth: 1))

                            Text(preset.title)
                                .font(.custom("ChartflowHand-Regular", size: 14))
                                .foregroundStyle(Color.chartflowText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .chartflowBox(
                        cornerRadius: 12,
                        wobble: 1.2,
                        fillColor: Color.chartflowBackground.opacity(0.72),
                        strokeColor: Color.chartflowText.opacity(0.25),
                        lineWidth: 1.2
                    )
                }
            }
        }
        .padding(12)
        .chartflowBox(
            cornerRadius: 16,
            wobble: 1.5,
            fillColor: Color.chartflowSurface,
            strokeColor: Color.chartflowText.opacity(0.35),
            lineWidth: 1.5
        )
    }
}

struct FriendShopItemCard<Preview: View>: View {
    let title: String
    let isSelected: Bool
    var isDisabled = false
    @ViewBuilder var preview: Preview
    let action: () -> Void

    var body: some View {
        Button {
            guard !isDisabled else { return }
            action()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.chartflowSurface)
                    preview
                        .padding(8)
                }
                .frame(height: 78)

                Text(title)
                    .font(.custom("ChartflowHand-Regular", size: 14))
                    .foregroundStyle(Color.chartflowText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(8)
            .opacity(isDisabled ? 0.35 : 1)
            .chartflowBox(
                cornerRadius: 18,
                wobble: 1.5,
                fillColor: isSelected ? Color(red: 0.85, green: 0.93, blue: 1.0) : Color.chartflowSurface,
                strokeColor: isSelected ? Color.blue : Color.chartflowText.opacity(0.45),
                lineWidth: isSelected ? 2.5 : 1.5
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct FriendAvatarLayer: View {
    let imageName: String
    var tintColor: Color? = nil

    @ViewBuilder
    var body: some View {
        if let tintColor {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .foregroundStyle(tintColor)
                .allowsHitTesting(false)
        } else {
            Image(imageName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .allowsHitTesting(false)
        }
    }
}

struct RoutineCardView: View {
    let chart: Chart
    @AppStorage("largerText") private var largerText = false
    @AppStorage("boldText") private var boldText = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chart.name)
                .font(.custom("ChartflowHand-Regular", size: largerText ? 23 : 20))
                .fontWeight(boldText ? .bold : .regular)
                .foregroundStyle(Color.chartflowText)
            Text("\(chart.events.count) step\(chart.events.count == 1 ? "" : "s")")
                .font(.custom("ChartflowHand-Regular", size: largerText ? 17 : 14))
                .fontWeight(boldText ? .semibold : .regular)
                .foregroundStyle(Color.chartflowSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .chartflowBox(cornerRadius: 16, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
    }
}

struct SettingsView: View {
    @Binding var defaultZoom: Double
    @Environment(\.dismiss) private var dismiss
    @AppStorage("boxMovementEffect") private var boxMovementEffectRaw = BoxMovementEffect.doodle.rawValue
    @AppStorage("backgroundPattern") private var backgroundPatternRaw = ChartflowBackgroundPattern.dots.rawValue
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("reduceBoxMotion") private var reduceBoxMotion = false
    @AppStorage("highContrastBoxes") private var highContrastBoxes = false
    @AppStorage("largerText") private var largerText = false
    @AppStorage("boldText") private var boldText = false
    @AppStorage("calmCelebrations") private var calmCelebrations = false

    private var boxMovementEffect: Binding<BoxMovementEffect> {
        Binding {
            BoxMovementEffect(rawValue: boxMovementEffectRaw) ?? .doodle
        } set: { newValue in
            boxMovementEffectRaw = newValue.rawValue
        }
    }

    private var backgroundPattern: Binding<ChartflowBackgroundPattern> {
        Binding {
            ChartflowBackgroundPattern(rawValue: backgroundPatternRaw) ?? .dots
        } set: { newValue in
            backgroundPatternRaw = newValue.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Box Movement") {
                    Picker("Effect", selection: boxMovementEffect) {
                        ForEach(BoxMovementEffect.allCases) { effect in
                            Text(effect.title).tag(effect)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(boxMovementEffect.wrappedValue.description)
                        .font(.custom("ChartflowHand-Regular", size: 15))
                        .foregroundStyle(.secondary)
                }

                Section("Background") {
                    Picker("Pattern", selection: backgroundPattern) {
                        ForEach(ChartflowBackgroundPattern.allCases) { pattern in
                            Text(pattern.title).tag(pattern)
                        }
                    }
                }

                Section("Appearance") {
                    Toggle("Dark mode", isOn: $darkModeEnabled)
                }

                Section("Accessibility") {
                    Toggle("Reduce box motion", isOn: $reduceBoxMotion)
                    Toggle("Higher contrast boxes", isOn: $highContrastBoxes)
                    Toggle("Larger routine text", isOn: $largerText)
                    Toggle("Bold text", isOn: $boldText)
                    Toggle("Simpler celebration", isOn: $calmCelebrations)
                }

                Section("Default Chart Zoom") {
                    Slider(value: $defaultZoom, in: 0.8...2.0, step: 0.1) {
                        Text("Default zoom")
                    }
                    Text("\(Int(defaultZoom * 100))%")
                        .font(.custom("ChartflowHand-Regular", size: 18))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HomeScreen(charts: .constant([Chart.sample, Chart.blank()]))
}
