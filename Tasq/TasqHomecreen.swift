import SwiftUI
import FirebaseAuth
import PhotosUI
import UIKit
internal import Combine

struct MindflowHomeScreen: View {
    @Binding var charts: [Chart]
    @Binding var defaultZoom: Double

    var body: some View {
        TasqWorkspaceView(charts: $charts, defaultZoom: $defaultZoom)
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
    @Environment(\.interfaceScale) private var interfaceScale

    var body: some View {
        HStack(spacing: 14) {
            TasqIcon(systemImage, size: 24 * interfaceScale)
                .frame(width: 40 * interfaceScale)

            Text(title)
                .font(.custom("ChartflowHand-Regular", size: 28 * interfaceScale))
                .fontWeight(boldText ? .black : .bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            TasqIcon("chevron.right", size: 18 * interfaceScale)
        }
        .foregroundStyle(Color.chartflowText)
        .frame(maxWidth: .infinity, minHeight: 78 * interfaceScale)
        .padding(.horizontal, 22 * interfaceScale)
        .chartflowBox(cornerRadius: 18, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
    }
}

struct HomeScreen: View {
    @Binding var charts: [Chart]
    @Binding var defaultZoom: Double
    @Environment(\.dismiss) private var dismiss
    @Environment(\.interfaceScale) private var interfaceScale
    @EnvironmentObject private var progressStore: UserProgressStore
    @State private var isDeleteMode = false
    @State private var showDeleteConfirmation = false
    @State private var chartToDelete: Chart? = nil
    @State private var showOnboardingSheet = false
    @State private var showScheduleTypeSheet = false

    let cardHeight: CGFloat = 72
    let cardSpacing: CGFloat = 16

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                ZStack(alignment: .bottomTrailing) {
                    PolkaDotBackground()
                        .ignoresSafeArea()

                    if showScheduleTypeSheet {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showScheduleTypeSheet = false
                                }
                            }
                            .zIndex(2)
                    }

                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                TasqIcon("house.fill", size: 22 * interfaceScale)
                                    .foregroundStyle(Color.chartflowText)
                            }
                            .padding(.leading, 20 * interfaceScale)
                            .accessibilityLabel("Back to Tasq")

                            Spacer(minLength: 0)
                            Text("Chartflow")
                                .font(.custom("ChartflowHand-Regular", size: 36 * interfaceScale))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.chartflowText)
                            Spacer(minLength: 0)
                            Button {
                                showOnboardingSheet = true
                            } label: {
                                TasqIcon("questionmark.circle", size: 22 * interfaceScale)
                                    .foregroundStyle(Color.chartflowText)
                            }
                            .padding(.trailing, 20 * interfaceScale)
                            .accessibilityLabel("Help")
                        }
                        .padding(.top, 20 * interfaceScale)
                        .padding(.bottom, 16 * interfaceScale)

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

                                            TasqIcon("minus.circle.fill", size: 22)
                                                .foregroundStyle(.red)
                                                .background(Color.chartflowSurface)
                                                .clipShape(Circle())
                                                .offset(x: 8, y: -8)
                                        } else {
                                            NavigationLink {
                                                ChartEditorView(chart: $charts[index], defaultZoom: defaultZoom)
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
                                        showScheduleTypeSheet = true
                                    } label: {
                                        TasqIcon("plus.circle.fill", size: 36)
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
                            TasqIcon(isDeleteMode ? "xmark" : "trash", size: 22)
                                .foregroundStyle(isDeleteMode ? Color.white : Color.red)
                        }
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 40)

                    if showScheduleTypeSheet {
                        NewScheduleDoodlyDialog(
                            createDiagram: {
                                charts.append(Chart.blank(type: .diagram))
                                progressStore.commitSave()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showScheduleTypeSheet = false
                                }
                            },
                            createDynamic: {
                                charts.append(Chart.blank(type: .dynamic))
                                progressStore.commitSave()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showScheduleTypeSheet = false
                                }
                            },
                            cancel: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showScheduleTypeSheet = false
                                }
                            }
                        )
                        .padding(.horizontal, 26)
                        .padding(.bottom, 34)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(3)
                    }
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
                            progressStore.commitSave()
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

private struct NewScheduleDoodlyDialog: View {
    let createDiagram: () -> Void
    let createDynamic: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Schedule")
                        .font(.custom("ChartflowHand-Regular", size: 28))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.chartflowText)
                    Text("Choose the schedule type to create.")
                        .font(.custom("ChartflowHand-Regular", size: 18))
                        .foregroundStyle(Color.chartflowSecondaryText)
                }

                Spacer(minLength: 0)

                Button(action: cancel) {
                    TasqIcon("xmark.circle.fill", size: 24)
                        .foregroundStyle(Color.chartflowSecondaryText)
                }
            }

            VStack(spacing: 10) {
                Button(action: createDiagram) {
                    Text("Diagram")
                        .font(.custom("ChartflowHand-Regular", size: 24))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.chartflowBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.chartflowText)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button(action: createDynamic) {
                    Text("Dynamic")
                        .font(.custom("ChartflowHand-Regular", size: 24))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.chartflowText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .chartflowBox(cornerRadius: 16, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
                }
            }
        }
        .padding(20)
        .chartflowBox(cornerRadius: 24, wobble: 2.5, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2.5)
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
        self == .skin7 ? "Original" : "Skin \(assetNumber)"
    }

    var imageName: String {
        // Keep the saved default ID so existing avatars pick up the supplied artwork.
        self == .skin7 ? "FriendCharacterSprite" : String(format: "FriendAsset%02d", assetNumber)
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
    var embedded = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthenticationStore
    @StateObject private var searchStore = FriendHubSearchStore()
    @State private var selectedTab = FriendHubTab.groups
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if searchStore.isLoadingProfile {
                    ProgressView()
                        .tint(Color.chartflowText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchStore.publicAccount == nil {
                    FriendHubOnboardingView(
                        username: $searchStore.usernameDraft,
                        message: searchStore.onboardingMessage,
                        isCreatingAccount: searchStore.isCreatingAccount,
                        canCreateAccount: searchStore.canCreateAccount,
                        createAccount: {
                            Task {
                                await searchStore.createPublicAccount(for: authStore.user?.uid)
                                if searchStore.publicAccount != nil {
                                    isSearchFocused = true
                                }
                            }
                        }
                    )
                } else {
                    VStack(spacing: 14) {
                        if selectedTab != .groups {
                            DoodleSectionTitle(title: "Better with a little company", subtitle: "Your people, in your corner.")
                                .padding(.horizontal, 22)
                        }
                        FriendHubDoodlyTabBar(selectedTab: $selectedTab)
                        .padding(.horizontal, 18)

                        if selectedTab == .groups, let account = searchStore.publicAccount {
                            FriendGroupHubView(account: account, friends: searchStore.friends)
                        } else if selectedTab == .search {
                            FriendHubSearchContentView(
                                query: $searchStore.query,
                                accounts: searchStore.accounts,
                                message: searchStore.searchMessage,
                                isSearching: searchStore.isSearching,
                                isSearchFocused: $isSearchFocused,
                                clearSearch: {
                                    searchStore.query = ""
                                    searchStore.scheduleSearch(excluding: authStore.user?.uid)
                                },
                                openProfile: { account in
                                    Task {
                                        await searchStore.selectProfile(account, currentUserID: authStore.user?.uid)
                                    }
                                }
                            )
                        } else if selectedTab == .friends {
                            FriendHubFriendsListView(
                                friends: searchStore.friends,
                                message: searchStore.friendsMessage,
                                isLoading: searchStore.isLoadingSocialData,
                                openProfile: { account in
                                    Task {
                                        await searchStore.selectProfile(account, currentUserID: authStore.user?.uid)
                                    }
                                },
                                openChat: { friend in
                                    searchStore.openChat(with: friend, currentUserID: authStore.user?.uid)
                                }
                            )
                        } else if selectedTab == .notifications {
                            FriendHubNotificationsView(
                                requests: searchStore.incomingRequests,
                                message: searchStore.notificationsMessage,
                                isLoading: searchStore.isLoadingSocialData,
                                acceptRequest: { request in
                                    Task {
                                        await searchStore.acceptFriendRequest(request, currentUserID: authStore.user?.uid)
                                    }
                                },
                                declineRequest: { request in
                                    Task {
                                        await searchStore.declineFriendRequest(request, currentUserID: authStore.user?.uid)
                                    }
                                },
                                openProfile: { account in
                                    Task {
                                        await searchStore.selectProfile(account, currentUserID: authStore.user?.uid)
                                    }
                                }
                            )
                        } else {
                            FriendHubProfileSettingsView(
                                username: $searchStore.profileUsernameDraft,
                                displayName: $searchStore.displayNameDraft,
                                profileIconName: $searchStore.profileIconNameDraft,
                                profileColorRaw: $searchStore.profileColorRawDraft,
                                bio: $searchStore.bioDraft,
                                status: $searchStore.statusDraft,
                                message: searchStore.profileMessage,
                                isSaving: searchStore.isSavingProfile,
                                canSave: searchStore.canSaveProfile,
                                saveProfile: {
                                    Task {
                                        await searchStore.saveProfileSettings(for: authStore.user?.uid)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.top, 18)
            .background(PolkaDotBackground().ignoresSafeArea())
            .task(id: authStore.user?.uid) {
                await searchStore.loadPublicAccount(for: authStore.user?.uid)
                isSearchFocused = false
            }
            .onChange(of: selectedTab) { _, newTab in
                isSearchFocused = newTab == .search
                if newTab == .friends || newTab == .notifications {
                    Task {
                        await searchStore.loadSocialData(for: authStore.user?.uid)
                    }
                }
            }
            .onChange(of: searchStore.query) { _, _ in
                searchStore.scheduleSearch(excluding: authStore.user?.uid)
            }
            .navigationTitle("Friend Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(item: $searchStore.selectedProfile) { account in
                FriendHubPublicProfileView(
                    account: account,
                    friends: searchStore.selectedProfileFriends,
                    message: searchStore.selectedProfileMessage,
                    isSendingFriendRequest: searchStore.isSendingFriendRequest,
                    isAlreadyFriend: searchStore.publicAccount?.friendIDs.contains(account.id) == true,
                    isCurrentUser: searchStore.publicAccount?.id == account.id,
                    sendFriendRequest: {
                        Task {
                            await searchStore.sendFriendRequest(to: account, from: authStore.user?.uid)
                        }
                    },
                    openChat: {
                        searchStore.openChat(with: account, currentUserID: authStore.user?.uid)
                    },
                    openFriendProfile: { friend in
                        Task {
                            await searchStore.selectProfile(friend, currentUserID: authStore.user?.uid)
                        }
                    }
                )
            }
            .sheet(item: $searchStore.selectedChatFriend, onDismiss: {
                searchStore.closeChat()
            }) { friend in
                FriendHubChatView(
                    friend: friend,
                    messages: searchStore.chatMessages,
                    currentUserID: authStore.user?.uid ?? "",
                    safetyAccepted: searchStore.chatSafetyAccepted,
                    chatBlocked: searchStore.chatBlocked,
                    isLoading: searchStore.isLoadingChat,
                    isSending: searchStore.isSendingMessage,
                    isSendingPicture: searchStore.isSendingPicture,
                    message: searchStore.chatMessage,
                    acceptSafety: {
                        searchStore.acceptChatSafety(for: friend.id)
                    },
                    sendMessage: { text in
                        await searchStore.sendChatMessage(text, currentUserID: authStore.user?.uid)
                    },
                    sendPicture: { imageData in
                        await searchStore.sendChatPicture(imageData, currentUserID: authStore.user?.uid)
                    },
                    reportPicture: { message in
                        Task {
                            await searchStore.reportInappropriatePicture(message, currentUserID: authStore.user?.uid)
                        }
                    }
                )
            }
        }
    }
}

private enum FriendHubTab: CaseIterable {
    case groups
    case search
    case friends
    case notifications
    case profile

    var title: String {
        switch self {
        case .groups: return "Hub"
        case .search: return "Search"
        case .friends: return "Friends"
        case .notifications: return "Notifs"
        case .profile: return "Profile"
        }
    }

    var iconName: String {
        switch self {
        case .groups: return "sparkles"
        case .search: return "magnifyingglass"
        case .friends: return "person.2.fill"
        case .notifications: return "bell.fill"
        case .profile: return "person.crop.circle"
        }
    }
}

private struct FriendHubDoodlyTabBar: View {
    @Binding var selectedTab: FriendHubTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FriendHubTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        TasqIcon(tab.iconName, size: 15)
                        Text(tab.title)
                            .font(.custom("ChartflowHand-Regular", size: 16))
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(selectedTab == tab ? Color.chartflowBackground : Color.chartflowText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Color.chartflowText : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .chartflowBox(cornerRadius: 20, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
    }
}

private struct FriendHubOnboardingView: View {
    @Binding var username: String
    let message: String
    let isCreatingAccount: Bool
    let canCreateAccount: Bool
    let createAccount: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 20)

            VStack(spacing: 12) {
                TasqIcon("person.crop.circle.badge.plus", size: 48)
                    .foregroundStyle(Color.chartflowText)

                Text("Create your public username")
                    .font(.custom("ChartflowHand-Regular", size: 30))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.chartflowText)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)

                Text("This is the name friends will search for in Friend Hub.")
                    .font(.custom("ChartflowHand-Regular", size: 18))
                    .foregroundStyle(Color.chartflowSecondaryText)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Text("@")
                        .font(.custom("ChartflowHand-Regular", size: 24))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.chartflowSecondaryText)

                    TextField("username", text: $username)
                        .font(.custom("ChartflowHand-Regular", size: 24))
                        .foregroundStyle(Color.chartflowText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onChange(of: username) { _, newValue in
                            username = newValue.friendHubUsernameInputFiltered
                        }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 58)
                .background(Color.chartflowBackground.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.chartflowText.opacity(0.35), lineWidth: 1.5)
                }

                Button {
                    createAccount()
                } label: {
                    HStack(spacing: 10) {
                        if isCreatingAccount {
                            ProgressView()
                                .tint(Color.chartflowBackground)
                        } else {
                            TasqIcon("checkmark.circle.fill", size: 22)
                        }

                        Text("Create Username")
                    }
                    .font(.custom("ChartflowHand-Regular", size: 22))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.chartflowBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canCreateAccount ? Color.chartflowText : Color.chartflowText.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canCreateAccount)

                Text(message)
                    .font(.custom("ChartflowHand-Regular", size: 17))
                    .foregroundStyle(message.contains("taken") || message.contains("Use only") ? .red : Color.chartflowSecondaryText)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 42)
            }
            .padding(20)
            .chartflowBox(cornerRadius: 20, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 22)
    }
}

struct AccountSetupWizardView: View {
    @Binding var birthday: Date
    @Binding var appearanceMode: TasqAppearanceMode
    @Binding var interfaceScale: Double
    let finishSetup: () -> Void
    @State private var currentStep = 0

    private var latestBirthday: Date {
        .now
    }

    private var isLastStep: Bool {
        currentStep == 2
    }

    var body: some View {
        ZStack {
            PolkaDotBackground()
                .ignoresSafeArea()

            ScrollView {
              VStack(spacing: 0) {
                Spacer(minLength: 24)

                ZStack {
                    Circle()
                        .fill(Color.chartflowSurface)
                        .frame(width: 110 * interfaceScale, height: 110 * interfaceScale)
                        .overlay {
                            WobblyCircle(wobble: 2)
                                .stroke(Color.chartflowText, lineWidth: 2.5)
                        }
                    TasqIcon(stepIcon, size: 46 * interfaceScale)
                        .foregroundStyle(Color.chartflowText)
                }
                .padding(.bottom, 30 * interfaceScale)

                Text(stepTitle)
                    .font(.custom("ChartflowHand-Regular", size: 36 * interfaceScale))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.chartflowText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28 * interfaceScale)

                Text(stepSubtitle)
                    .font(.custom("ChartflowHand-Regular", size: 22 * interfaceScale))
                    .foregroundStyle(Color.chartflowText.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32 * interfaceScale)
                    .padding(.top, 10 * interfaceScale)

                stepContent
                    .padding(22 * interfaceScale)
                    .frame(maxWidth: 560)

                Spacer(minLength: 16)

                HStack(spacing: 8 * interfaceScale) {
                    ForEach(0..<3, id: \.self) { step in
                        Circle()
                            .fill(step == currentStep ? Color.chartflowText : Color.chartflowSecondaryText.opacity(0.35))
                            .frame(width: 10 * interfaceScale, height: 10 * interfaceScale)
                            .animation(.easeInOut, value: currentStep)
                    }
                }
                .padding(.bottom, 24 * interfaceScale)

                HStack(spacing: 12 * interfaceScale) {
                    if currentStep > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                currentStep -= 1
                            }
                        } label: {
                            TasqIcon("chevron.left", size: 20 * interfaceScale)
                                .foregroundStyle(Color.chartflowText)
                                .frame(width: 52 * interfaceScale, height: 56 * interfaceScale)
                                .background(Color.chartflowSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if isLastStep {
                                finishSetup()
                            } else {
                                currentStep += 1
                            }
                        }
                    } label: {
                        Text(isLastStep ? "Finish Setup" : "Next")
                            .font(.custom("ChartflowHand-Regular", size: 22 * interfaceScale))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.chartflowBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18 * interfaceScale)
                            .background(Color.chartflowText)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 28 * interfaceScale)

                Spacer().frame(height: 44 * interfaceScale)
              }
              .frame(maxWidth: 680)
              .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            DatePicker(
                "Birth date",
                selection: $birthday,
                in: ...latestBirthday,
                displayedComponents: .date
            )
            .font(.custom("ChartflowHand-Regular", size: 22 * interfaceScale))
            .datePickerStyle(.graphical)
            .padding(18 * interfaceScale)
            .chartflowBox(cornerRadius: 18, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
        case 1:
            HStack(spacing: 12 * interfaceScale) {
                ForEach(TasqAppearanceMode.allCases) { mode in
                    AccountAppearanceChoice(
                        mode: mode,
                        isSelected: appearanceMode == mode
                    ) {
                        appearanceMode = mode
                    }
                }
            }
            .padding(18 * interfaceScale)
            .chartflowBox(cornerRadius: 18, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
        default:
            VStack(spacing: 16 * interfaceScale) {
                AccountSizingPreview(scale: interfaceScale)

                HStack {
                    Text("Small")
                    Slider(value: $interfaceScale, in: 0.8...1.35, step: 0.05)
                        .tint(Color.chartflowText)
                    Text("Large")
                }
                .font(.custom("ChartflowHand-Regular", size: 16 * interfaceScale))
                .foregroundStyle(Color.chartflowSecondaryText)

                Text("\(Int(interfaceScale * 100))%")
                    .font(.custom("ChartflowHand-Regular", size: 20 * interfaceScale))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.chartflowText)
            }
            .padding(18 * interfaceScale)
            .chartflowBox(cornerRadius: 18, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
        }
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: return "Your birthday"
        case 1: return "Choose appearance"
        default: return "Choose sizing"
        }
    }

    private var stepSubtitle: String {
        switch currentStep {
        case 0: return "This belongs to your Tasq account."
        case 1: return "Pick how the app should look."
        default: return "Change button and font size."
        }
    }

    private var stepIcon: String {
        switch currentStep {
        case 0: return "calendar"
        case 1: return "circle.lefthalf.filled"
        default: return "textformat.size"
        }
    }
}

private struct AccountSizingPreview: View {
    let scale: Double

    var body: some View {
        VStack(spacing: 12 * scale) {
            Text("Preview")
                .font(.custom("ChartflowHand-Regular", size: 20 * scale))
                .fontWeight(.bold)
                .foregroundStyle(Color.chartflowText)

            HStack(spacing: 10 * scale) {
                TasqIcon("list.bullet.rectangle.fill", size: 22 * scale)
                    .frame(width: 34 * scale)

                VStack(alignment: .leading, spacing: 3 * scale) {
                    Text("Chartflow")
                        .font(.custom("ChartflowHand-Regular", size: 24 * scale))
                        .fontWeight(.bold)
                    Text("Buttons and labels resize")
                        .font(.custom("ChartflowHand-Regular", size: 15 * scale))
                        .foregroundStyle(Color.chartflowSecondaryText)
                }

                Spacer(minLength: 0)

                TasqIcon("chevron.right", size: 16 * scale)
            }
            .foregroundStyle(Color.chartflowText)
            .frame(height: 64 * scale)
            .padding(.horizontal, 16 * scale)
            .chartflowBox(cornerRadius: 16, wobble: 2, fillColor: .chartflowBackground, strokeColor: .chartflowText, lineWidth: 2)
        }
        .animation(.easeInOut(duration: 0.15), value: scale)
    }
}

private struct AccountAppearanceChoice: View {
    @Environment(\.interfaceScale) private var interfaceScale
    let mode: TasqAppearanceMode
    let isSelected: Bool
    let action: () -> Void

    private var previewBackground: Color {
        switch mode {
        case .system: return Color(red: 0.64, green: 0.78, blue: 0.92)
        case .light: return Color(red: 0.92, green: 0.97, blue: 1.0)
        case .dark: return Color(red: 0.04, green: 0.06, blue: 0.12)
        }
    }

    private var previewForeground: Color {
        mode == .dark ? .white : .black
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8 * interfaceScale) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(previewBackground)

                    VStack(spacing: 5 * interfaceScale) {
                        HStack(spacing: 3 * interfaceScale) {
                            TasqIcon(mode.iconName, size: 8 * interfaceScale)
                                .foregroundStyle(previewForeground.opacity(0.82))
                            Spacer()
                        }

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.blue)
                            .frame(height: 10 * interfaceScale)

                        Spacer(minLength: 0)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(mode == .dark ? Color.black.opacity(0.75) : Color.white.opacity(0.92))
                            .frame(height: 25 * interfaceScale)
                            .overlay {
                                HStack(spacing: 5 * interfaceScale) {
                                    Circle().fill(.red).frame(width: 6 * interfaceScale, height: 6 * interfaceScale)
                                    Circle().fill(.yellow).frame(width: 6 * interfaceScale, height: 6 * interfaceScale)
                                    Circle().fill(.green).frame(width: 6 * interfaceScale, height: 6 * interfaceScale)
                                }
                            }
                    }
                    .padding(7 * interfaceScale)
                }
                .frame(height: 62 * interfaceScale)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isSelected ? Color.blue : Color.chartflowText.opacity(0.25), lineWidth: isSelected ? 3 : 1)
                }

                Text(mode.title)
                    .font(.custom("ChartflowHand-Regular", size: 17 * interfaceScale))
                    .fontWeight(.bold)
                    .foregroundStyle(isSelected ? Color.chartflowText : Color.chartflowSecondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct FriendHubSearchContentView: View {
    @Environment(\.interfaceScale) private var interfaceScale
    @Binding var query: String
    let accounts: [FriendHubAccount]
    let message: String
    let isSearching: Bool
    var isSearchFocused: FocusState<Bool>.Binding
    let clearSearch: () -> Void
    let openProfile: (FriendHubAccount) -> Void

    var body: some View {
        VStack(spacing: 14 * interfaceScale) {
            HStack(spacing: 12 * interfaceScale) {
                TasqIcon("magnifyingglass", size: 18 * interfaceScale)
                    .foregroundStyle(Color.chartflowSecondaryText)

                TextField("Search usernames", text: $query)
                    .font(.custom("ChartflowHand-Regular", size: 22 * interfaceScale))
                    .foregroundStyle(Color.chartflowText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(isSearchFocused)
                    .submitLabel(.search)

                if isSearching {
                    ProgressView()
                        .tint(Color.chartflowText)
                } else if !query.isEmpty {
                    Button(action: clearSearch) {
                        TasqIcon("xmark.circle.fill", size: 18 * interfaceScale)
                            .foregroundStyle(Color.chartflowSecondaryText)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16 * interfaceScale)
            .frame(minHeight: 58 * interfaceScale)
            .background(Color.chartflowSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.chartflowText, lineWidth: 2)
            }
            .padding(.horizontal, 18 * interfaceScale)

            ScrollView {
                LazyVStack(spacing: 10 * interfaceScale) {
                    if !message.isEmpty {
                        Text(message)
                            .font(.custom("ChartflowHand-Regular", size: 19 * interfaceScale))
                            .foregroundStyle(Color.chartflowSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.top, 34 * interfaceScale)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(accounts) { account in
                        Button {
                            openProfile(account)
                        } label: {
                            FriendHubAccountRow(account: account)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18 * interfaceScale)
                .padding(.bottom, 18 * interfaceScale)
            }
        }
    }
}

private struct FriendHubFriendsListView: View {
    @Environment(\.interfaceScale) private var interfaceScale
    let friends: [FriendHubAccount]
    let message: String
    let isLoading: Bool
    let openProfile: (FriendHubAccount) -> Void
    let openChat: (FriendHubAccount) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10 * interfaceScale) {
                if isLoading {
                    ProgressView()
                        .tint(Color.chartflowText)
                        .padding(.top, 34 * interfaceScale)
                } else if !message.isEmpty {
                    Text(message)
                        .font(.custom("ChartflowHand-Regular", size: 19 * interfaceScale))
                        .foregroundStyle(Color.chartflowSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 34 * interfaceScale)
                        .frame(maxWidth: .infinity)
                }

                ForEach(friends) { friend in
                    HStack(spacing: 10 * interfaceScale) {
                        Button {
                            openProfile(friend)
                        } label: {
                            FriendHubAccountRow(account: friend)
                        }
                        .buttonStyle(.plain)

                        Button {
                            openChat(friend)
                        } label: {
                            TasqIcon("message.fill", size: 20 * interfaceScale)
                                .foregroundStyle(Color.chartflowBackground)
                                .frame(width: 48 * interfaceScale, height: 48 * interfaceScale)
                                .background(Color.chartflowText)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Chat with \(friend.username)")
                    }
                }
            }
            .padding(.horizontal, 18 * interfaceScale)
            .padding(.bottom, 18 * interfaceScale)
        }
    }
}

private struct FriendHubChatFriendRow: View {
    @Environment(\.interfaceScale) private var interfaceScale
    let friend: FriendHubAccount
    let openProfile: (FriendHubAccount) -> Void
    let openChat: (FriendHubAccount) -> Void

    var body: some View {
        HStack(spacing: 10 * interfaceScale) {
            Button {
                openProfile(friend)
            } label: {
                FriendHubAccountRow(account: friend)
            }
            .buttonStyle(.plain)

            Button {
                openChat(friend)
            } label: {
                TasqIcon("message.fill", size: 20 * interfaceScale)
                    .foregroundStyle(Color.chartflowBackground)
                    .frame(width: 48 * interfaceScale, height: 48 * interfaceScale)
                    .background(Color.chartflowText)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Chat with \(friend.username)")
        }
    }
}

private struct FriendHubNotificationsView: View {
    @Environment(\.interfaceScale) private var interfaceScale
    let requests: [FriendHubFriendRequest]
    let message: String
    let isLoading: Bool
    let acceptRequest: (FriendHubFriendRequest) -> Void
    let declineRequest: (FriendHubFriendRequest) -> Void
    let openProfile: (FriendHubAccount) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10 * interfaceScale) {
                if isLoading {
                    ProgressView()
                        .tint(Color.chartflowText)
                        .padding(.top, 34 * interfaceScale)
                } else if !message.isEmpty {
                    Text(message)
                        .font(.custom("ChartflowHand-Regular", size: 19 * interfaceScale))
                        .foregroundStyle(Color.chartflowSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 34 * interfaceScale)
                        .frame(maxWidth: .infinity)
                }

                ForEach(requests) { request in
                    FriendHubRequestRow(
                        request: request,
                        acceptRequest: acceptRequest,
                        declineRequest: declineRequest,
                        openProfile: openProfile
                    )
                }
            }
            .padding(.horizontal, 18 * interfaceScale)
            .padding(.bottom, 18 * interfaceScale)
        }
    }
}

private struct FriendHubProfileSettingsView: View {
    @Environment(\.interfaceScale) private var interfaceScale
    @Binding var username: String
    @Binding var displayName: String
    @Binding var profileIconName: String
    @Binding var profileColorRaw: String
    @Binding var bio: String
    @Binding var status: String
    let message: String
    let isSaving: Bool
    let canSave: Bool
    let saveProfile: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14 * interfaceScale) {
                FriendHubProfilePreview(
                    account: FriendHubAccount(
                        id: "preview",
                        username: username.friendHubUsernameInputFiltered,
                        displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                        profileIconName: profileIconName,
                        profileColorRaw: profileColorRaw,
                        bio: bio,
                        status: status,
                        friendIDs: []
                    )
                )

                VStack(spacing: 12 * interfaceScale) {
                    FriendHubProfileFieldLabel("Username")
                    FriendHubTextInput(prefix: "@", placeholder: "username", text: $username)
                        .onChange(of: username) { _, newValue in
                            username = newValue.friendHubUsernameInputFiltered
                        }

                    FriendHubProfileFieldLabel("Display name")
                    FriendHubTextInput(prefix: nil, placeholder: "Display name", text: $displayName)
                        .onChange(of: displayName) { _, newValue in
                            displayName = String(newValue.prefix(32))
                        }

                    FriendHubProfileFieldLabel("Profile picture")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10 * interfaceScale), count: 4), spacing: 10 * interfaceScale) {
                        ForEach(FriendHubProfileStyle.icons, id: \.self) { iconName in
                            Button {
                                profileIconName = iconName
                            } label: {
                                TasqIcon(iconName, size: 23 * interfaceScale)
                                    .foregroundStyle(profileIconName == iconName ? Color.chartflowBackground : Color.chartflowText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48 * interfaceScale)
                                    .background(profileIconName == iconName ? Color.chartflowText : Color.chartflowBackground.opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    FriendHubProfileFieldLabel("Color")
                    HStack(spacing: 10 * interfaceScale) {
                        ForEach(FriendHubProfileStyle.colorNames, id: \.self) { colorRaw in
                            Button {
                                profileColorRaw = colorRaw
                            } label: {
                                Circle()
                                    .fill(FriendHubProfileStyle.color(for: colorRaw))
                                    .frame(width: 34 * interfaceScale, height: 34 * interfaceScale)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.chartflowText, lineWidth: profileColorRaw == colorRaw ? 3 : 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    FriendHubProfileFieldLabel("Status")
                    FriendHubTextInput(prefix: nil, placeholder: "Working on chores", text: $status)
                        .onChange(of: status) { _, newValue in
                            status = String(newValue.prefix(40))
                        }

                    FriendHubProfileFieldLabel("Bio")
                    TextField("Bio", text: $bio, axis: .vertical)
                        .font(.custom("ChartflowHand-Regular", size: 20 * interfaceScale))
                        .foregroundStyle(Color.chartflowText)
                        .lineLimit(2...3)
                        .padding(.horizontal, 16 * interfaceScale)
                        .padding(.vertical, 12 * interfaceScale)
                        .background(Color.chartflowBackground.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.chartflowText.opacity(0.35), lineWidth: 1.5)
                        }
                        .onChange(of: bio) { _, newValue in
                            bio = String(newValue.prefix(90))
                        }

                    Button(action: saveProfile) {
                        HStack(spacing: 10 * interfaceScale) {
                            if isSaving {
                                ProgressView()
                                    .tint(Color.chartflowBackground)
                            } else {
                                TasqIcon("checkmark.circle.fill", size: 22 * interfaceScale)
                            }

                            Text("Save Profile")
                        }
                        .font(.custom("ChartflowHand-Regular", size: 22 * interfaceScale))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.chartflowBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14 * interfaceScale)
                        .background(canSave ? Color.chartflowText : Color.chartflowText.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!canSave)

                    Text(message)
                        .font(.custom("ChartflowHand-Regular", size: 17 * interfaceScale))
                        .foregroundStyle(message.contains("saved") ? .green : Color.chartflowSecondaryText)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 34)
                }
                .padding(18 * interfaceScale)
                .chartflowBox(cornerRadius: 20, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
            }
            .padding(.horizontal, 18 * interfaceScale)
            .padding(.bottom, 18 * interfaceScale)
        }
    }
}

private struct FriendHubAccountRow: View {
    @Environment(\.interfaceScale) private var interfaceScale
    let account: FriendHubAccount

    var body: some View {
        HStack(spacing: 12 * interfaceScale) {
            FriendHubProfilePicture(account: account, size: 46 * interfaceScale)

            VStack(alignment: .leading, spacing: 3 * interfaceScale) {
                Text(account.displayName.isEmpty ? "@\(account.username)" : account.displayName)
                    .font(.custom("ChartflowHand-Regular", size: 22 * interfaceScale))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.chartflowText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("@\(account.username)")
                    .font(.custom("ChartflowHand-Regular", size: 16 * interfaceScale))
                    .foregroundStyle(Color.chartflowSecondaryText)
                    .lineLimit(1)

                if !account.status.isEmpty {
                    Text(account.status)
                        .font(.custom("ChartflowHand-Regular", size: 15 * interfaceScale))
                        .foregroundStyle(Color.chartflowSecondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14 * interfaceScale)
        .padding(.vertical, 12 * interfaceScale)
        .chartflowBox(cornerRadius: 16, wobble: 1.5, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.5)
    }
}

private struct FriendHubRequestRow: View {
    @Environment(\.interfaceScale) private var interfaceScale
    let request: FriendHubFriendRequest
    let acceptRequest: (FriendHubFriendRequest) -> Void
    let declineRequest: (FriendHubFriendRequest) -> Void
    let openProfile: (FriendHubAccount) -> Void

    var body: some View {
        VStack(spacing: 12 * interfaceScale) {
            Button {
                openProfile(request.sender)
            } label: {
                FriendHubAccountRow(account: request.sender)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10 * interfaceScale) {
                Button {
                    acceptRequest(request)
                } label: {
                    Label {
                        Text("Accept")
                    } icon: {
                        TasqIcon("checkmark.circle.fill", size: 18 * interfaceScale)
                    }
                        .font(.custom("ChartflowHand-Regular", size: 18 * interfaceScale))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.chartflowBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10 * interfaceScale)
                        .background(Color.chartflowText)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    declineRequest(request)
                } label: {
                    Label {
                        Text("Decline")
                    } icon: {
                        TasqIcon("xmark.circle.fill", size: 18 * interfaceScale)
                    }
                        .font(.custom("ChartflowHand-Regular", size: 18 * interfaceScale))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.chartflowText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10 * interfaceScale)
                        .background(Color.chartflowSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.chartflowText, lineWidth: 1.5)
                        }
                }
            }
        }
        .padding(12 * interfaceScale)
        .chartflowBox(cornerRadius: 18, wobble: 1.5, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.5)
    }
}

private struct FriendHubPublicProfileView: View {
    @Environment(\.dismiss) private var dismiss
    let account: FriendHubAccount
    let friends: [FriendHubAccount]
    let message: String
    let isSendingFriendRequest: Bool
    let isAlreadyFriend: Bool
    let isCurrentUser: Bool
    let sendFriendRequest: () -> Void
    let openChat: () -> Void
    let openFriendProfile: (FriendHubAccount) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    FriendHubProfilePreview(account: account)

                    if isAlreadyFriend {
                        Button(action: openChat) {
                            HStack(spacing: 10) {
                                TasqIcon("message.fill", size: 21)
                                Text("Chat")
                            }
                            .font(.custom("ChartflowHand-Regular", size: 21))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.chartflowBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.chartflowText)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    } else if !isCurrentUser {
                        Button(action: sendFriendRequest) {
                            HStack(spacing: 10) {
                                if isSendingFriendRequest {
                                    ProgressView()
                                        .tint(Color.chartflowBackground)
                                } else {
                                    TasqIcon("person.badge.plus.fill", size: 21)
                                }

                                Text("Send Friend Request")
                            }
                            .font(.custom("ChartflowHand-Regular", size: 21))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.chartflowBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.chartflowText)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isSendingFriendRequest)
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(.custom("ChartflowHand-Regular", size: 17))
                            .foregroundStyle(message.contains("sent") ? .green : Color.chartflowSecondaryText)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Friends")
                            .font(.custom("ChartflowHand-Regular", size: 23))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.chartflowText)

                        if friends.isEmpty {
                            Text("No friends yet.")
                                .font(.custom("ChartflowHand-Regular", size: 18))
                                .foregroundStyle(Color.chartflowSecondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(friends) { friend in
                                Button {
                                    openFriendProfile(friend)
                                } label: {
                                    FriendHubAccountRow(account: friend)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .chartflowBox(cornerRadius: 18, wobble: 1.5, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 1.5)
                }
                .padding(18)
            }
            .background(PolkaDotBackground().ignoresSafeArea())
            .navigationTitle("@\(account.username)")
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

private struct FriendHubChatView: View {
    @Environment(\.dismiss) private var dismiss
    let friend: FriendHubAccount
    let messages: [FriendHubChatMessage]
    let currentUserID: String
    let safetyAccepted: Bool
    let chatBlocked: Bool
    let isLoading: Bool
    let isSending: Bool
    let isSendingPicture: Bool
    let message: String
    let acceptSafety: () -> Void
    let sendMessage: (String) async -> Bool
    let sendPicture: (Data) async -> Bool
    let reportPicture: (FriendHubChatMessage) -> Void
    @State private var draft = ""
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending && safetyAccepted && !chatBlocked
    }

    private var canSendPicture: Bool {
        safetyAccepted && !chatBlocked && !isSendingPicture
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if safetyAccepted {
                    chatContent
                } else {
                    FriendHubChatSafetyView(
                        friend: friend,
                        acceptSafety: acceptSafety
                    )
                }
            }
            .background(PolkaDotBackground().ignoresSafeArea())
            .navigationTitle("@\(friend.username)")
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

    private var chatContent: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .tint(Color.chartflowText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(messages) { chatMessage in
                                FriendHubChatBubble(
                                    message: chatMessage,
                                    isMine: chatMessage.senderID == currentUserID,
                                    reportPicture: reportPicture
                                )
                                .id(chatMessage.id)
                            }

                            if messages.isEmpty {
                                Text("No messages yet.")
                                    .font(.custom("ChartflowHand-Regular", size: 19))
                                    .foregroundStyle(Color.chartflowSecondaryText)
                                    .padding(.top, 34)
                            }
                        }
                        .padding(18)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            if !message.isEmpty {
                Text(message)
                    .font(.custom("ChartflowHand-Regular", size: 16))
                    .foregroundStyle(message.contains("blocked") ? .red : Color.chartflowSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    if isSendingPicture {
                        ProgressView()
                            .tint(Color.chartflowText)
                    } else {
                        TasqIcon("photo.fill", size: 20)
                    }
                }
                .frame(width: 46, height: 46)
                .background(Color.chartflowSurface)
                .foregroundStyle(canSendPicture ? Color.chartflowText : Color.chartflowText.opacity(0.35))
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.chartflowText.opacity(0.3), lineWidth: 1.5)
                }
                .disabled(!canSendPicture)
                .accessibilityLabel("Send picture")

                TextField("Message", text: $draft, axis: .vertical)
                    .font(.custom("ChartflowHand-Regular", size: 20))
                    .foregroundStyle(Color.chartflowText)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.chartflowSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.chartflowText.opacity(0.35), lineWidth: 1.5)
                    }
                    .onChange(of: draft) { _, newValue in
                        draft = String(newValue.prefix(500))
                    }
                    .disabled(chatBlocked)

                Button {
                    Task {
                        let sent = await sendMessage(draft)
                        if sent {
                            draft = ""
                        }
                    }
                } label: {
                    if isSending {
                        ProgressView()
                            .tint(Color.chartflowBackground)
                    } else {
                        TasqIcon("paperplane.fill", size: 19)
                    }
                }
                .frame(width: 46, height: 46)
                .background(canSend ? Color.chartflowText : Color.chartflowText.opacity(0.35))
                .foregroundStyle(Color.chartflowBackground)
                .clipShape(Circle())
                .disabled(!canSend)
                .accessibilityLabel("Send message")
            }
            .padding(14)
            .background(Color.chartflowBackground.opacity(0.96))
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }

                Task {
                    guard let originalData = try? await newItem.loadTransferable(type: Data.self),
                          let compressedData = FriendHubImageProcessor.compressedJPEGData(from: originalData) else {
                        selectedPhotoItem = nil
                        return
                    }

                    let sent = await sendPicture(compressedData)
                    if sent {
                        selectedPhotoItem = nil
                    }
                }
            }
        }
    }
}

private struct FriendHubChatSafetyView: View {
    let friend: FriendHubAccount
    let acceptSafety: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                FriendHubProfilePreview(account: friend)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Before you chat")
                        .font(.custom("ChartflowHand-Regular", size: 28))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.chartflowText)

                    FriendHubSafetyReminder(icon: "creditcard.fill", text: "Never send money, gift cards, codes, passwords, or banking info.")
                    FriendHubSafetyReminder(icon: "location.slash.fill", text: "Do not share your home address, school, phone number, email, or exact location.")
                    FriendHubSafetyReminder(icon: "person.fill.xmark", text: "Do not agree to private meetups or keep scary requests secret.")
                    FriendHubSafetyReminder(icon: "photo.fill", text: "Do not send private or inappropriate photos. Reported pictures block the chat.")
                    FriendHubSafetyReminder(icon: "hand.raised.fill", text: "Stop chatting and tell a trusted adult if someone pressures, threatens, or tricks you.")

                    Button(action: acceptSafety) {
                        Label {
                            Text("I Understand")
                        } icon: {
                            TasqIcon("checkmark.shield.fill", size: 20)
                        }
                            .font(.custom("ChartflowHand-Regular", size: 22))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.chartflowBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.chartflowText)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.top, 6)
                }
                .padding(18)
                .chartflowBox(cornerRadius: 20, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
            }
            .padding(18)
        }
    }
}

private struct FriendHubSafetyReminder: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TasqIcon(icon, size: 18)
                .foregroundStyle(Color.chartflowText)
                .frame(width: 24)

            Text(text)
                .font(.custom("ChartflowHand-Regular", size: 18))
                .foregroundStyle(Color.chartflowSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FriendHubChatBubble: View {
    let message: FriendHubChatMessage
    let isMine: Bool
    let reportPicture: (FriendHubChatMessage) -> Void

    private var messageImage: UIImage? {
        guard let imageDataBase64 = message.imageDataBase64,
              let data = Data(base64Encoded: imageDataBase64) else {
            return nil
        }

        return UIImage(data: data)
    }

    var body: some View {
        HStack {
            if isMine {
                Spacer(minLength: 42)
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 8) {
                if let messageImage {
                    Image(uiImage: messageImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.chartflowText.opacity(0.24), lineWidth: 1.5)
                        }
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.custom("ChartflowHand-Regular", size: 19))
                        .foregroundStyle(isMine ? Color.chartflowBackground : Color.chartflowText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if message.hasImage && !isMine {
                    Button {
                        reportPicture(message)
                    } label: {
                        Label {
                            Text("Report image")
                        } icon: {
                            TasqIcon("hand.raised.fill", size: 14)
                        }
                        .font(.custom("ChartflowHand-Regular", size: 15))
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .chartflowBox(cornerRadius: 18, wobble: 1.3,
                          fillColor: isMine ? .chartflowText : .chartflowSurface,
                          strokeColor: .chartflowText.opacity(isMine ? 1 : 0.5), lineWidth: 1.3)

            if !isMine {
                Spacer(minLength: 42)
            }
        }
    }
}

private enum FriendHubImageProcessor {
    static func compressedJPEGData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let maxDimension: CGFloat = 720
        let largestDimension = max(image.size.width, image.size.height)
        let scale = largestDimension > maxDimension ? maxDimension / largestDimension : 1
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return renderedImage.jpegData(compressionQuality: 0.62)
    }
}

private struct FriendHubProfilePreview: View {
    let account: FriendHubAccount

    var body: some View {
        HStack(spacing: 14) {
            FriendHubProfilePicture(account: account, size: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName.isEmpty ? account.username : account.displayName)
                    .font(.custom("ChartflowHand-Regular", size: 26))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.chartflowText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("@\(account.username.isEmpty ? "username" : account.username)")
                    .font(.custom("ChartflowHand-Regular", size: 17))
                    .foregroundStyle(Color.chartflowSecondaryText)
                    .lineLimit(1)

                if !account.bio.isEmpty {
                    Text(account.bio)
                        .font(.custom("ChartflowHand-Regular", size: 16))
                        .foregroundStyle(Color.chartflowSecondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .chartflowBox(cornerRadius: 20, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
    }
}

private struct FriendHubProfilePicture: View {
    let account: FriendHubAccount
    let size: CGFloat

    var body: some View {
        TasqIcon(account.profileIconName, size: size * 0.48)
            .foregroundStyle(Color.chartflowBackground)
            .frame(width: size, height: size)
            .background(FriendHubProfileStyle.color(for: account.profileColorRaw))
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.chartflowText, lineWidth: 1.5)
            }
    }
}

private struct FriendHubTextInput: View {
    let prefix: String?
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            if let prefix {
                Text(prefix)
                    .font(.custom("ChartflowHand-Regular", size: 23))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.chartflowSecondaryText)
            }

            TextField(placeholder, text: $text)
                .font(.custom("ChartflowHand-Regular", size: 21))
                .foregroundStyle(Color.chartflowText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .chartflowBox(cornerRadius: 14, wobble: 1.2, fillColor: .chartflowBackground,
                      strokeColor: .chartflowText.opacity(0.5), lineWidth: 1.3)
    }
}

private struct FriendHubProfileFieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.custom("ChartflowHand-Regular", size: 17))
            .fontWeight(.bold)
            .foregroundStyle(Color.chartflowSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum FriendHubProfileStyle {
    static let icons = [
        "person.crop.circle.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "bolt.circle.fill",
        "leaf.circle.fill",
        "moon.circle.fill",
        "sparkles",
        "checkmark.seal.fill"
    ]

    static let colorNames = ["blue", "green", "pink", "orange", "purple", "teal"]

    static func color(for rawValue: String) -> Color {
        switch rawValue {
        case "green":
            return .green
        case "pink":
            return .pink
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "teal":
            return .teal
        default:
            return .blue
        }
    }
}

private extension String {
    var friendHubUsernameInputFiltered: String {
        let normalized = folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        let filteredScalars = normalized.unicodeScalars.filter { allowedCharacters.contains($0) }
        return String(String.UnicodeScalarView(filteredScalars)).prefixString(maxLength: 20)
    }

    func prefixString(maxLength: Int) -> String {
        String(prefix(maxLength))
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
                                Label {
                                    Text("Save")
                                } icon: {
                                    TasqIcon("checkmark", size: 16)
                                }
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
                TasqIcon("nosign", size: 16)
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
                TasqIcon("nosign", size: 16)
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
                TasqIcon("nosign", size: 16)
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
                TasqIcon("nosign", size: 16)
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
                TasqIcon("nosign", size: 16)
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
    @Environment(\.interfaceScale) private var interfaceScale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chart.name)
                .font(.custom("ChartflowHand-Regular", size: (largerText ? 23 : 20) * interfaceScale))
                .fontWeight(boldText ? .bold : .regular)
                .foregroundStyle(Color.chartflowText)
            Text("\(chart.scheduleType.title) - \(chart.events.count) step\(chart.events.count == 1 ? "" : "s")")
                .font(.custom("ChartflowHand-Regular", size: (largerText ? 17 : 14) * interfaceScale))
                .fontWeight(boldText ? .semibold : .regular)
                .foregroundStyle(Color.chartflowSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16 * interfaceScale)
        .padding(.horizontal, 20 * interfaceScale)
        .chartflowBox(cornerRadius: 16, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
    }
}

struct SettingsView: View {
    @Binding var defaultZoom: Double
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthenticationStore
    @Environment(\.interfaceScale) private var interfaceScale
    @AppStorage("boxMovementEffect") private var boxMovementEffectRaw = BoxMovementEffect.doodle.rawValue
    @AppStorage("backgroundPattern") private var backgroundPatternRaw = TasqBackgroundPattern.dots.rawValue
    @AppStorage("appearanceMode") private var appearanceModeRaw = TasqAppearanceMode.system.rawValue
    @AppStorage("interfaceScale") private var interfaceScaleSetting = 1.0
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

    private var backgroundPattern: Binding<TasqBackgroundPattern> {
        Binding {
            TasqBackgroundPattern(rawValue: backgroundPatternRaw) ?? .dots
        } set: { newValue in
            backgroundPatternRaw = newValue.rawValue
        }
    }

    private var appearanceMode: Binding<TasqAppearanceMode> {
        Binding {
            TasqAppearanceMode(rawValue: appearanceModeRaw) ?? .system
        } set: { newValue in
            newValue.save()
            appearanceModeRaw = newValue.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PolkaDotBackground()
                    .ignoresSafeArea()

                VStack(spacing: 14 * interfaceScale) {
                    HStack {
                        Spacer(minLength: 0)
                        Text("Settings")
                            .font(.custom("ChartflowHand-Regular", size: 30 * interfaceScale))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.chartflowText)
                        Spacer(minLength: 0)
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.custom("ChartflowHand-Regular", size: 18 * interfaceScale))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.chartflowBackground)
                                .padding(.horizontal, 18 * interfaceScale)
                                .padding(.vertical, 10 * interfaceScale)
                                .background(Color.chartflowText)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20 * interfaceScale)
                    .padding(.top, 18 * interfaceScale)

                    ScrollView {
                        VStack(spacing: 18 * interfaceScale) {
                            DoodlySettingsSection(title: "Account") {
                                VStack(alignment: .leading, spacing: 8 * interfaceScale) {
                                    Text(authStore.displayName)
                                        .font(.custom("ChartflowHand-Regular", size: 22 * interfaceScale))
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.chartflowText)
                                    Text(authStore.email)
                                        .font(.custom("ChartflowHand-Regular", size: 16 * interfaceScale))
                                        .foregroundStyle(Color.chartflowSecondaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Divider()

                                Button(role: .destructive) {
                                    authStore.signOut()
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12 * interfaceScale) {
                                        TasqIcon("rectangle.portrait.and.arrow.right", size: 20 * interfaceScale)
                                            .foregroundStyle(.blue)
                                        Text("Sign Out")
                                            .font(.custom("ChartflowHand-Regular", size: 22 * interfaceScale))
                                            .fontWeight(.bold)
                                            .foregroundStyle(.red)
                                        Spacer(minLength: 0)
                                    }
                                }
                            }

                            DoodlySettingsSection(title: "Box Movement") {
                                DoodlyOptionRow(
                                    options: BoxMovementEffect.allCases,
                                    selection: boxMovementEffect,
                                    title: { $0.title }
                                )
                                Text(boxMovementEffect.wrappedValue.description)
                                    .font(.custom("ChartflowHand-Regular", size: 15 * interfaceScale))
                                    .foregroundStyle(Color.chartflowSecondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            DoodlySettingsSection(title: "Background") {
                                DoodlyOptionRow(
                                    options: TasqBackgroundPattern.allCases,
                                    selection: backgroundPattern,
                                    title: { $0.title }
                                )
                            }

                            DoodlySettingsSection(title: "Appearance") {
                                DoodlyOptionRow(
                                    options: TasqAppearanceMode.allCases,
                                    selection: appearanceMode,
                                    title: { $0.title }
                                )
                            }

                            DoodlySettingsSection(title: "Interface Sizing") {
                                AccountSizingPreview(scale: interfaceScaleSetting)
                                Slider(value: $interfaceScaleSetting, in: 0.8...1.35, step: 0.05) {
                                    Text("Interface size")
                                }
                                .tint(Color.chartflowText)
                                Text("\(Int(interfaceScaleSetting * 100))%")
                                    .font(.custom("ChartflowHand-Regular", size: 18 * interfaceScale))
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.chartflowText)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            DoodlySettingsSection(title: "Accessibility") {
                                DoodlyToggleRow(title: "Reduce box motion", isOn: $reduceBoxMotion)
                                DoodlyToggleRow(title: "Higher contrast boxes", isOn: $highContrastBoxes)
                                DoodlyToggleRow(title: "Larger routine text", isOn: $largerText)
                                DoodlyToggleRow(title: "Bold text", isOn: $boldText)
                                DoodlyToggleRow(title: "Simpler celebration", isOn: $calmCelebrations)
                            }

                            DoodlySettingsSection(title: "Default Chart Zoom") {
                                Slider(value: $defaultZoom, in: 0.8...2.0, step: 0.1) {
                                    Text("Default zoom")
                                }
                                .tint(Color.chartflowText)
                                Text("\(Int(defaultZoom * 100))%")
                                    .font(.custom("ChartflowHand-Regular", size: 18 * interfaceScale))
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.chartflowText)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.horizontal, 20 * interfaceScale)
                        .padding(.bottom, 28 * interfaceScale)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct DoodlySettingsSection<Content: View>: View {
    @Environment(\.interfaceScale) private var interfaceScale
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * interfaceScale) {
            Text(title)
                .font(.custom("ChartflowHand-Regular", size: 24 * interfaceScale))
                .fontWeight(.bold)
                .foregroundStyle(Color.chartflowSecondaryText)
                .padding(.leading, 4 * interfaceScale)

            VStack(spacing: 12 * interfaceScale) {
                content
            }
            .padding(18 * interfaceScale)
            .chartflowBox(cornerRadius: 24, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)
        }
    }
}

private struct DoodlyOptionRow<Option: Identifiable & Equatable>: View {
    @Environment(\.interfaceScale) private var interfaceScale
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 8 * interfaceScale) {
            ForEach(options) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(.custom("ChartflowHand-Regular", size: 17 * interfaceScale))
                        .fontWeight(.bold)
                        .foregroundStyle(selection == option ? Color.chartflowBackground : Color.chartflowText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10 * interfaceScale)
                        .background(selection == option ? Color.chartflowText : Color.chartflowBackground.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DoodlyToggleRow: View {
    @Environment(\.interfaceScale) private var interfaceScale
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 12 * interfaceScale) {
                Text(title)
                    .font(.custom("ChartflowHand-Regular", size: 18 * interfaceScale))
                    .foregroundStyle(Color.chartflowText)
                Spacer(minLength: 0)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Color.chartflowText : Color.chartflowBackground.opacity(0.75))
                        .frame(width: 52 * interfaceScale, height: 30 * interfaceScale)
                    Circle()
                        .fill(isOn ? Color.chartflowBackground : Color.chartflowSecondaryText)
                        .frame(width: 24 * interfaceScale, height: 24 * interfaceScale)
                        .padding(.horizontal, 3 * interfaceScale)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeScreen(charts: .constant([Chart.sample, Chart.blank()]), defaultZoom: .constant(1.3))
}
