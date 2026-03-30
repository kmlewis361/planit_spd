import SwiftUI

struct HomeView: View {
    var onSeeDetails: ((UUID) -> Void)? = nil
    var onLoggedOut: (()-> Void)? = nil
    var onCreateEvent: (()-> Void)? = nil
//    var username: String = ""
    @State private var events: [Event] = [Event(name: "Birthday Party", description: "a party?", invitees: ["Kathy", "Stacy"], duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: []), Event(name: "Brunch",  description: "casual brunch", invitees: ["Kathy", "Stacy"],duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])]
    var body: some View {
        
        Button("Create EVent", systemImage: "plus"){
            print("plus clicked")
            onCreateEvent?()
        }
        .font(.title)
        .labelStyle(.iconOnly)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding()
        
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
        .onAppear{if(globalUsername==""){onLoggedOut?()}}
        .padding()
    }
}

#Preview {
    HomeView()
}
