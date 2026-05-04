import SwiftUI

extension Notification.Name {
    /// Posted after submitting a response so `EventDetailsView` can refresh ranked times.
    static let planitEventResponsesDidChange = Notification.Name("planitEventResponsesDidChange")
}

var globalUsername: String = ""
/// Stable CloudKit user record name for the signed-in iCloud account (ties profile + invites to iCloud).
var globalCloudKitOwnerRecordName: String = ""

// Centralized route enum so we can navigate to multiple destinations programmatically
enum Route: Hashable {
    case welcome
    case login
    case home
    case eventDetails(eventId: UUID)
    case eventCreation
    case eventResponse(eventId: UUID)
}

struct AppRoot: View {
    @State private var path = NavigationPath()
    /// Bumped whenever the stack returns to root so `HomeView` can refetch CloudKit (root views do not get `onAppear` again when a pushed screen is popped).
    @State private var homeEventsRefreshTrigger = 0
    /// Merged into the home list after save; cleared when `HomeView` applies it (avoids racing a nil-only refresh against CloudKit eventual consistency).
    @State private var pendingHomeListEvent: Event?
    @State private var pendingResponseForDetails: [UUID: Response] = [:]

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                homeEventsRefreshTrigger: homeEventsRefreshTrigger,
                pendingHomeListEvent: $pendingHomeListEvent,
                onRespond: { eventId in
                    path.append(Route.eventResponse(eventId: eventId))
                },
                onSeeDetails: { eventId in
                    path.append(Route.eventDetails(eventId: eventId))
                },
                onLoggedOut: {
                    path.append(Route.login)
                },
                onCreateEvent: {
                    path.append(Route.eventCreation)
                    print("AppRoot: navigating to event creation")
                }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .welcome:
                    // When the user taps "Maybe later..." the closure below will clear the stack
                    // and append .home so HomeView becomes the root of the navigation stack.
                    WelcomeView(onDoIt: {
                        path.removeLast(path.count)
                        path.append(Route.eventCreation)
                    }, onMaybeLater: {
                        path.removeLast(path.count)
                        path.removeLast(path.count)
                       
                    })
                case .login:
                    LoginView(onLogin: { showWelcome in
                        path.removeLast(path.count)
                        if showWelcome {
                            path.append(Route.welcome)
                        }
                    })
                    .navigationBarBackButtonHidden(true)
                case .home:
                    HomeView(
                        homeEventsRefreshTrigger: homeEventsRefreshTrigger,
                        pendingHomeListEvent: $pendingHomeListEvent,
                        onSeeDetails: { eventId in
                            path.removeLast(path.count)
                            path.append(Route.eventDetails(eventId: eventId))
                        },
                        onCreateEvent: {
                            path.append(Route.eventCreation)
                            print("AppRoot: navigating to event creation")
                        }
                    )
                case .eventDetails(let eventId):
                    EventDetailsView(eventId: eventId, pendingResponse: pendingResponseForDetails[eventId])
                case .eventCreation:
                    EventCreationView(onSend: { created in
                        pendingHomeListEvent = created
                        path = NavigationPath()
                    })
                case .eventResponse(let eventId):
                    EventResponseView(eventId: eventId, onSubmit: { response in
                        pendingResponseForDetails[eventId] = response
                        path.removeLast(path.count)
                        path.append(Route.eventDetails(eventId: eventId))
                    })
                }
            
            }
        }
        .onChange(of: path.count) { oldCount, newCount in
            if newCount == 0, oldCount > 0 {
                homeEventsRefreshTrigger += 1
            }
        }
    }
}

#Preview {
    AppRoot()
}
