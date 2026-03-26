import SwiftUI

// Centralized route enum so we can navigate to multiple destinations programmatically
enum Route: Hashable {
    case welcome(username: String)
    case login
    case home(username: String)
    case eventDetails(eventId: UUID)
//    case eventDetail(event: Event)
    // add more cases for additional screens as needed
}

struct AppRoot: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(onSeeDetails: { eventId in
                path.append(Route.eventDetails(eventId: eventId))
            }, onLoggedOut: {
                path.append(Route.login)
            }, username: "")

            
            
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .welcome(let username):
                    // When the user taps "Maybe later..." the closure below will clear the stack
                    // and append .home so HomeView becomes the root of the navigation stack.
                    WelcomeView(username: username, onMaybeLater: {
                        path.removeLast(path.count)
                       
                    })
                case .login:
                    LoginView(onLogin: { username in
                                path.removeLast(path.count)
                                path.append(Route.welcome(username: username))
                                
                    })
                    .navigationBarBackButtonHidden(true)
                case .home(let username):
                    HomeView(onSeeDetails: { eventId in
                        path.append(Route.eventDetails(eventId: eventId))
                    }, username: username)
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
