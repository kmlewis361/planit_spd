import SwiftUI
import CloudKit
var events: [Event] = [Event(name: "Birthday Party", description: "a party?", invitees: ["Kathy", "Stacy"], duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: []), Event(name: "Brunch",  description: "casual brunch", invitees: ["Kathy", "Stacy"],duration: 1000, bestTime: Time(startTime: Date(), endTime: Date()), responses: [])]
struct HomeView: View {
    @State var localEvents: [Event] = events
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
        ForEach(localEvents) { event in
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
            .onAppear {
                print(events)
                if globalUsername == "" {
                    localEvents = events
                    onLoggedOut?()
                    return
                }
                Task {
                    let fetched = await fetchEventsFromCloudKit()
                    await MainActor.run {
                        localEvents = fetched
                    }
                }
            }
        .padding()
    }

    private func fetchEventsFromCloudKit() async -> [Event] {
        let database = CKContainer.default().publicCloudDatabase
        let query = CKQuery(recordType: "Event", predicate: NSPredicate(value: true))
        do {
            let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil)
            var events: [Event] = []
            events.reserveCapacity(matchResults.count)
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    print("CloudKit Event id: \(record.recordID.recordName)")
                    events.append(event(from: record))
                case .failure(let error):
                    print("CloudKit record error: \(error.localizedDescription)")
                }
            }
            return events
        } catch {
            print("CloudKit query failed: \(error.localizedDescription)")
            return []
        }
    }

    private func event(from record: CKRecord) -> Event {
        let idString = record["id"] as? String
        let id = idString.flatMap { UUID(uuidString: $0) } ?? UUID()
        let name = (record["name"] as? String) ?? ""
        let description = (record["description"] as? String) ?? ""
        return Event(
            id: id,
            name: name,
            description: description,
            invitees: [],
            duration: 0,
            bestTime: Time(startTime: Date(), endTime: Date()),
            responses: []
        )
    }
}

#Preview {
    HomeView()
}


