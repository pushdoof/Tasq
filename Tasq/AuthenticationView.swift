import SwiftUI
import FirebaseAuth
import FirebaseCore
internal import Combine
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
final class AuthenticationStore: ObservableObject {
    @Published private(set) var user: User?
    @Published var errorMessage: String?
    @Published var isWorking = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    var isSignedIn: Bool {
        user != nil
    }

    var displayName: String {
        if let name = user?.displayName, !name.isEmpty {
            return name
        }
        return user?.email ?? "Signed in"
    }

    var email: String {
        user?.email ?? "No email on this account"
    }

    init() {
        user = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    func signIn(email: String, password: String) async {
        await runAuthAction {
            _ = try await Auth.auth().signIn(withEmail: email.trimmed, password: password)
        }
    }

    func createAccount(email: String, password: String) async {
        await runAuthAction {
            _ = try await Auth.auth().createUser(withEmail: email.trimmed, password: password)
        }
    }

    func resetPassword(email: String) async {
        let trimmedEmail = email.trimmed
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Enter your email first."
            return
        }

        await runAuthAction {
            try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
            self.errorMessage = "Password reset email sent."
        }
    }

    func signInWithGoogle() async {
        #if canImport(GoogleSignIn)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google sign-in needs CLIENT_ID in GoogleService-Info.plist. Add an iOS OAuth client in Firebase, then download the updated plist."
            return
        }

        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            errorMessage = "Could not find a window to present Google sign-in."
            return
        }

        await runAuthAction {
            let configuration = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = configuration
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthenticationError.missingGoogleIDToken
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            _ = try await Auth.auth().signIn(with: credential)
        }
        #else
        errorMessage = "Google sign-in needs the GoogleSignIn Swift package added to the Tasq app target."
        #endif
    }

    func signOut() {
        do {
            #if canImport(GoogleSignIn)
            GIDSignIn.sharedInstance.signOut()
            #endif
            try Auth.auth().signOut()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runAuthAction(_ action: @escaping () async throws -> Void) async {
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum AuthenticationError: LocalizedError {
    case missingGoogleIDToken

    var errorDescription: String? {
        switch self {
        case .missingGoogleIDToken:
            return "Google did not return a sign-in token."
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var authStore: AuthenticationStore
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @FocusState private var focusedField: AuthField?

    private var canSubmit: Bool {
        !email.trimmed.isEmpty && password.count >= 6 && !authStore.isWorking
    }

    var body: some View {
        ZStack {
            PolkaDotBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 28)

                    VStack(spacing: 10) {
                        Text("Tasq")
                            .font(.custom("ChartflowHand-Regular", size: 48))
                            .fontWeight(.black)
                            .foregroundStyle(Color.chartflowText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(isCreatingAccount ? "Create your account" : "Sign in to your account")
                            .font(.custom("ChartflowHand-Regular", size: 25))
                            .foregroundStyle(Color.chartflowSecondaryText)
                    }
                    .padding(.top, 16)

                    VStack(spacing: 14) {
                        AuthTextField(
                            title: "Email",
                            text: $email,
                            systemImage: "envelope.fill",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        )
                        .focused($focusedField, equals: .email)

                        AuthSecureField(title: "Password", text: $password)
                            .focused($focusedField, equals: .password)

                        Button {
                            submitEmailPassword()
                        } label: {
                            HStack(spacing: 10) {
                                if authStore.isWorking {
                                    ProgressView()
                                        .tint(Color.chartflowBackground)
                                } else {
                                    TasqIcon(isCreatingAccount ? "person.badge.plus.fill" : "person.fill.checkmark", size: 22)
                                }

                                Text(isCreatingAccount ? "Create Account" : "Sign In")
                            }
                            .font(.custom("ChartflowHand-Regular", size: 22))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.chartflowBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSubmit ? Color.chartflowText : Color.chartflowText.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(!canSubmit)

                        Button {
                            Task { await authStore.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                TasqIcon("g.circle.fill", size: 22)
                                Text("Continue with Google")
                            }
                            .font(.custom("ChartflowHand-Regular", size: 22))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.chartflowText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.chartflowSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.chartflowText, lineWidth: 2)
                            }
                        }
                        .disabled(authStore.isWorking)

                        if let errorMessage = authStore.errorMessage {
                            Text(errorMessage)
                                .font(.custom("ChartflowHand-Regular", size: 17))
                                .foregroundStyle(errorMessage.contains("sent") ? .green : .red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 2)
                        }
                    }
                    .padding(22)
                    .chartflowBox(cornerRadius: 20, wobble: 2, fillColor: .chartflowSurface, strokeColor: .chartflowText, lineWidth: 2)

                    VStack(spacing: 12) {
                        Button(isCreatingAccount ? "Already have an account? Sign in" : "New here? Create an account") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isCreatingAccount.toggle()
                                authStore.errorMessage = nil
                            }
                        }

                        Button("Forgot password?") {
                            Task { await authStore.resetPassword(email: email) }
                        }
                        .opacity(isCreatingAccount ? 0 : 1)
                        .disabled(isCreatingAccount || authStore.isWorking)
                    }
                    .font(.custom("ChartflowHand-Regular", size: 18))
                    .foregroundStyle(Color.chartflowText)

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func submitEmailPassword() {
        focusedField = nil
        Task {
            if isCreatingAccount {
                await authStore.createAccount(email: email, password: password)
            } else {
                await authStore.signIn(email: email, password: password)
            }
        }
    }
}

private enum AuthField: Hashable {
    case email
    case password
}

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let systemImage: String
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType

    var body: some View {
        HStack(spacing: 12) {
            TasqIcon(systemImage, size: 18)
                .frame(width: 30)

            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(textContentType)
        }
        .font(.custom("ChartflowHand-Regular", size: 21))
        .foregroundStyle(Color.chartflowText)
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(Color.chartflowBackground.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.chartflowText.opacity(0.35), lineWidth: 1.5)
        }
    }
}

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            TasqIcon("lock.fill", size: 18)
                .frame(width: 30)

            SecureField(title, text: $text)
                .textContentType(.password)
        }
        .font(.custom("ChartflowHand-Regular", size: 21))
        .foregroundStyle(Color.chartflowText)
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(Color.chartflowBackground.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.chartflowText.opacity(0.35), lineWidth: 1.5)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationStore())
}
