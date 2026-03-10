import SwiftUI

// Centralized route enum so we can navigate to multiple destinations programmatically
enum Route: Hashable {
    case welcome(username: String)
    case home
    // add more cases for additional screens as needed
}

struct AppRoot: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            // Initial view is the LoginView. When the login completes we append a route to the path.
            LoginView(onLogin: { username in
                // Push the welcome screen and pass the username
                path.removeLast(path.count)
                path.append(Route.welcome(username: username))
            })
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .welcome(let username):
                    WelcomeView(username: username, onMaybeLater: {
                        path.removeLast(path.count)
                        path.append(.home)
                    })
                case .home:
                    ContentView()
                }
            }
        }
    }
}

#Preview {
    AppRoot()
}
