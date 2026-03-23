import SwiftUI

// Centralized route enum so we can navigate to multiple destinations programmatically
enum Route: Hashable {
    case welcome(username: String)
    case home
    case details(eventId: UUID)
}

struct AppRoot: View {
    @State private var path = NavigationPath()
    @State private var isLoggedIn: Bool = false
    @State private var username: String? = nil
    @State private var initialRoute: Route? = nil

    var body: some View {
        Group {
            if !isLoggedIn {
                // Show the login screen as the app root when logged out.
                LoginView(onLogin: { name in
                    print("AppRoot: onLogin called with username=\(name)")
                    // Queue the initial route and switch to the logged-in navigation stack.
                    // Do all state mutations asynchronously to avoid changing state during view updates.
                    DispatchQueue.main.async {
                        username = name
                        initialRoute = .welcome(username: name)
                        isLoggedIn = true
                    }
                })
            } else {
                // Delegate the logged-in navigation to LoggedInView so all .navigationDestination modifiers
                // are attached while a NavigationStack is present (avoids runtime warnings).
                LoggedInView(path: $path, initialRoute: $initialRoute, username: username ?? "")
            }
        }
        .onChange(of: isLoggedIn) { new in
            print("AppRoot: isLoggedIn changed -> \(new)")
        }
        .onChange(of: path) { newPath in
            print("AppRoot: path changed, count=\(newPath.count)")
        }
    }
}

#Preview {
    AppRoot()
}
