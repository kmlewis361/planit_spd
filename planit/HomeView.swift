import SwiftUI
var events: [Event] = [Event(name: "Birthday Party", description: "a party?", invitees: ["Kathy", "Stacy"], duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: []), Event(name: "Brunch",  description: "casual brunch", invitees: ["Kathy", "Stacy"],duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])]
struct HomeView: View {
    var onRespond: ((UUID) -> Void)? = nil
    var onSeeDetails: ((UUID) -> Void)? = nil
    var onLoggedOut: (()-> Void)? = nil
    var onCreateEvent: (()-> Void)? = nil
//    var username: String = ""
    
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
                VStack{
                    Text(event.name)
                        .font(.title2)
                    HStack {
                        Spacer()
                        Button("Respond"){
                            onRespond?(event.id)
                        }
                        Spacer()
                        Button("See details"){
                            onSeeDetails?(event.id)
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 6)
            }
            Spacer()
        }
        .onAppear{print(events)
            if(globalUsername==""){onLoggedOut?()}}
        .padding()
    }
}

#Preview {
    HomeView()
}
