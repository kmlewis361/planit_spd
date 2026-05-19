import SwiftUI
import CloudKit
var events: [Event] = [Event(name: "", description: "", invitees: [], duration: 3600, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])]
struct HomeView: View {
    /// When this value changes (after returning to the navigation root), CloudKit is queried again.
    var homeEventsRefreshTrigger: Int = 0
    /// Set when an event is created so the next refresh can merge it in before CloudKit lists it.
    var pendingHomeListEvent: Binding<Event?> = .constant(nil)

    @State var localEvents: [Event] = events
    @State private var signedInUsernameLabel: String = ""
    @State private var loadErrorMessage: String?
    var onRespond: ((UUID) -> Void)? = nil
    var onSeeDetails: ((UUID) -> Void)? = nil
    var onLoggedOut: (()-> Void)? = nil
    var onCreateEvent: (()-> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if !signedInUsernameLabel.isEmpty {
                    Text("@\(planItHandleForDisplay(signedInUsernameLabel))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    onCreateEvent?()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(PlanItTheme.fieldBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create event")
            }
            .padding(.top, 8)
            .padding(.bottom, 4)

            Text("My Plans")
                .planItScreenTitle()
                .padding(.bottom, 12)

            if let loadErrorMessage {
                HStack(spacing: 10) {
                    Text(loadErrorMessage)
                    Spacer(minLength: 0)
                    Button("Dismiss") { self.loadErrorMessage = nil }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .buttonStyle(.plain)
                }
                .planItErrorBanner()
                .padding(.bottom, 10)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(localEvents) { event in
                        if !event.name.isEmpty {
                            eventCard(event)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .planItScreen()
        .onAppear {
            refreshSignedInUsernameLabel()
        }
        .task(id: homeEventsRefreshTrigger) {
            refreshSignedInUsernameLabel()
            await refreshLocalEventsFromCloudKit()
        }
    }

    @ViewBuilder
    private func eventCard(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(event.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            HStack(spacing: 20) {
                Button("Respond") {
                    onRespond?(event.id)
                }
                .buttonStyle(PlanItTextLinkButtonStyle())

                Button("See details") {
                    onSeeDetails?(event.id)
                }
                .buttonStyle(PlanItTextLinkButtonStyle())
            }
        }
        .planItCard()
    }

    private func refreshSignedInUsernameLabel() {
        signedInUsernameLabel = normalizedPlanItUsername(globalUsername)
    }

    /// Avoid `@alice` → `@@alice` if stored handle ever includes a leading `@`.
    private func planItHandleForDisplay(_ normalized: String) -> String {
        normalized.hasPrefix("@") ? String(normalized.dropFirst()) : normalized
    }

    @MainActor
    private func refreshLocalEventsFromCloudKit() async {
        if globalUsername == "" {
            localEvents = events
            onLoggedOut?()
            return
        }
        let me = normalizedPlanItUsername(globalUsername).lowercased()
        let fetched: [Event]
        do {
            fetched = try await fetchEventsFromCloudKit(whereInviteeUsernameLowercased: me)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn’t load your events right now. Please check your connection and iCloud, then try again."
            localEvents = []
            return
        }
        let pending = pendingHomeListEvent.wrappedValue
        if let pending, !fetched.contains(where: { $0.id == pending.id }), eventIncludesInviteeLowercased(pending, usernameLowercased: me) {
            var merged = fetched
            merged.insert(pending, at: 0)
            localEvents = merged
            pendingHomeListEvent.wrappedValue = nil
            return
        }
        if pending != nil {
            pendingHomeListEvent.wrappedValue = nil
        }
        localEvents = fetched
    }
}

#Preview {
    HomeView()
}
