import SwiftUI

// Centralized route enum so we can navigate to multiple destinations programmatically
enum Route: Hashable {
    case welcome(username: String)
    case home
    case eventDetails(eventId: UUID)
//    case eventDetail(event: Event)
    // add more cases for additional screens as needed
}

struct AppRoot: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            // Initial view is the LoginView. When the login completes we append a route to the path.
            LoginView(onLogin: { username in
                // Clear any existing path and push the welcome screen as the only destination
                path.removeLast(path.count)
                path.append(Route.welcome(username: username))
            })
            
            
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .welcome(let username):
                    // When the user taps "Maybe later..." the closure below will clear the stack
                    // and append .home so HomeView becomes the root of the navigation stack.
                    WelcomeView(username: username, onMaybeLater: {
                        path.removeLast(path.count)
                        path.append(Route.home)
                    })
                case .home:
                    // Ensure .home explicitly maps to HomeView
                    HomeView(onSeeDetails: { eventId in
                        path.append(Route.eventDetails(eventId: eventId))
                    })
                    
                case .eventDetails(let eventId):
                    EventDetailsView(eventId: eventId)
                }
            }
        }
    }
}

#Preview {
    AppRoot()
}
