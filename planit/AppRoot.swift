import SwiftUI
var globalUsername: String = ""

// Centralized route enum so we can navigate to multiple destinations programmatically
enum Route: Hashable {
    case welcome
    case login
    case home
    case eventDetails(eventId: UUID)
    case eventCreation
}

struct AppRoot: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(onSeeDetails: { eventId in
                path.append(Route.eventDetails(eventId: eventId))
            }, onLoggedOut: {
                path.append(Route.login)
            }, onCreateEvent:{path.append(Route.eventCreation)
                print("AppRoot: navigating to event creation")})

            
            
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .welcome:
                    // When the user taps "Maybe later..." the closure below will clear the stack
                    // and append .home so HomeView becomes the root of the navigation stack.
                    WelcomeView(onMaybeLater: {
                        path.removeLast(path.count)
                        path.removeLast(path.count)
                       
                    })
                case .login:
                    LoginView(onLogin: {
                                path.removeLast(path.count)
                                path.append(Route.welcome)
                                
                    })
                    .navigationBarBackButtonHidden(true)
                case .home:
                    HomeView(onSeeDetails: { eventId in
                        path.append(Route.eventDetails(eventId: eventId))
                    }, onCreateEvent:{path.append(Route.eventCreation)
                    print("AppRoot: navigating to event creation")})
                case .eventDetails(let eventId):
                    EventDetailsView(eventId: eventId)
                case.eventCreation:
                    EventCreationView()
                }
            
            }
        }
    }
}

#Preview {
    AppRoot()
}
