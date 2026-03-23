import SwiftUI

// LoggedInView is responsible for the NavigationStack and its destinations when the user is logged in.
struct LoggedInView: View {
    @Binding var path: NavigationPath
    @Binding var initialRoute: Route?
    var username: String

    var body: some View {
        NavigationStack(path: $path) {
            if let route = initialRoute {
                VStack(spacing: 12) {
                    Text("Welcome, \(username)")
                        .font(.title)
                    Text("Preparing your dashboard...")
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        path = NavigationPath()
                        path.append(route)
                        initialRoute = nil
                    }
                }
            } else {
                WelcomeView(username: username, onMaybeLater: {
                    DispatchQueue.main.async {
                        path = NavigationPath()
                        path.append(Route.home)
                    }
                })
                .navigationBarBackButtonHidden(true)
            }
        }
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .welcome(let name):
                WelcomeView(username: name, onMaybeLater: {
                    DispatchQueue.main.async {
                        path = NavigationPath()
                        path.append(Route.home)
                    }
                })
                .navigationBarBackButtonHidden(true)

            case .home:
                HomeView(onSeeDetails: { eventId in
                    DispatchQueue.main.async {
                        path.append(Route.details(eventId: eventId))
                    }
                })
                .navigationBarBackButtonHidden(true)

            case .details(let eventId):
                EventDetailsView(eventId: eventId)
            }
        }
    }
}

#Preview {
    LoggedInView(path: .constant(NavigationPath()), initialRoute: .constant(.welcome(username: "Preview")), username: "Preview")
}
