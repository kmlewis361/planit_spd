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
                localEvents = events
                if globalUsername == "" {
                    onLoggedOut?()
                    return
                }
                Task {
                    await fetchAndPrintCloudKitEventIDs()
                }
            }
        .padding()
    }

    private func fetchAndPrintCloudKitEventIDs() async {
        let database = CKContainer.default().publicCloudDatabase
        let query = CKQuery(recordType: "Event", predicate: NSPredicate(value: true))
        do {
            let (matchResults, _) = try await database.records(matching: query, inZoneWith: nil)
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    print("CloudKit Event id: \(record.recordID.recordName)")
                case .failure(let error):
                    print("CloudKit record error: \(error.localizedDescription)")
                }
            }
        } catch {
            print("CloudKit query failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    HomeView()
}


