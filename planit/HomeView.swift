import SwiftUI

struct HomeView: View {
    var onSeeDetails: ((UUID) -> Void)? = nil
    var onLoggedOut: (()-> Void)? = nil
    var username: String = ""
    @State private var events: [Event] = [Event(name: "Birthday Party", duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: []), Event(name: "Brunch", duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])]
    var body: some View {
        VStack {
            ForEach(events) { event in
                HStack {
                    Text(event.name)
                    Spacer()
                    Button(action: {
                        onSeeDetails?(event.id)
                    }) {
                        Text("See details")
                    }
                }
                .padding(.vertical, 6)
            }
            Spacer()
        }
        .onAppear{if(username==""){onLoggedOut?()}}
        .padding()
    }
}

#Preview {
    HomeView()
}
