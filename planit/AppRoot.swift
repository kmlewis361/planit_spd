//
//  AppRoot.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI

// Centralized route enum so we can navigate to multiple destinations programmatically
enum Route: Hashable {
    case welcome(username: String)
    case home
    case details(eventId: UUID)
}

struct AppRoot: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            // Keep LoginView as the root of the stack so pushing WelcomeView leaves Login in history.
            LoginView(onLogin: { username in
                            // Push the welcome screen and pass the username
                            // Clear any existing path and push the welcome screen as the only destination
                            path.removeLast(path.count)
                            path.append(Route.welcome(username: username))
                        })
        }
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .welcome(let name):
                WelcomeView(username: name, onMaybeLater: {
                    // Navigate to the home route from WelcomeView
                    path.append(Route.home)
                })
                .navigationBarBackButtonHidden(false)

            case .home:
                HomeView(onSeeDetails: { eventId in
                    path.append(Route.details(eventId: eventId))
                })
                .navigationBarBackButtonHidden(false)

            case .details(let eventId):
                EventDetailsView(eventId: eventId)
            }
        }
    }
}

#Preview {
    AppRoot()
}
