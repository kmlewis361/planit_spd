//
//  DisplayEventsView.swift
//  planit
//
//  Created by Elise Wong-McBride on 4/13/26.
//

import SwiftUI

struct DisplayEventsView: View {
    var events: [Event] = []
    var onRespond: ((UUID) -> Void)? = nil
    var onSeeDetails: ((UUID) -> Void)? = nil
    var body: some View {
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
    }
}

#Preview {
    DisplayEventsView()
}
