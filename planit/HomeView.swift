import SwiftUI
import CloudKit
var events: [Event] = [Event(name: "", description: "", invitees: [], duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])]
struct HomeView: View {
    /// When this value changes (after returning to the navigation root), CloudKit is queried again.
    var homeEventsRefreshTrigger: Int = 0
    /// Set when an event is created so the next refresh can merge it in before CloudKit lists it.
    var pendingHomeListEvent: Binding<Event?> = .constant(nil)

    @State var localEvents: [Event] = events
    var onRespond: ((UUID) -> Void)? = nil
    var onSeeDetails: ((UUID) -> Void)? = nil
    var onLoggedOut: (()-> Void)? = nil
    var onCreateEvent: (()-> Void)? = nil
//    var username: String = ""
    
    var body: some View {
        VStack {
            Button("Create EVent", systemImage: "plus") {
                print("plus clicked")
                onCreateEvent?()
            }
            .font(.title)
            .labelStyle(.iconOnly)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
            ForEach(localEvents) { event in
                VStack {
                    if(!event.name.isEmpty){
                        Text(event.name)
                            .font(.title2)
                        
                        HStack {
                            Spacer()
                            Button("Respond") {
                                onRespond?(event.id)
                            }
                            Spacer()
                            Button("See details") {
                                onSeeDetails?(event.id)
                            }
                            Spacer()
                        }
                    
                    }
                }
                .padding(.vertical, 6)
            }
            Spacer()
        }
        .padding()
        .onAppear { print(events) }
        .task(id: homeEventsRefreshTrigger) {
            await refreshLocalEventsFromCloudKit()
        }
    }

    @MainActor
    private func refreshLocalEventsFromCloudKit() async {
        if globalUsername == "" {
            localEvents = events
            onLoggedOut?()
            return
        }
        var fetched = await fetchEventsFromCloudKit()
        let pending = pendingHomeListEvent.wrappedValue
        if let pending, !fetched.contains(where: { $0.id == pending.id }) {
            fetched.insert(pending, at: 0)
        }
        if pending != nil {
            pendingHomeListEvent.wrappedValue = nil
        }
        localEvents = fetched
    }

//    private func event(from record: CKRecord) -> Event {
//        let idString = record["id"] as? String
//        let id = idString.flatMap { UUID(uuidString: $0) } ?? UUID()
//        let name = (record["name"] as? String) ?? ""
//        let description = (record["description"] as? String) ?? ""
//        return Event(
//            id: id,
//            name: name,
//            description: description,
//            invitees: [],
//            duration: 0,
//            bestTime: Time(startTime: Date(), endTime: Date()),
//            responses: []
//        )
//    }
}

#Preview {
    HomeView()
}
