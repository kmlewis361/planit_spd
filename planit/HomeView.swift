//
//  HomeView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/10/26.
//

import SwiftUI

struct HomeView: View {
    @State private var events: [Event] = []
    var body: some View {
        VStack{
            ForEach(events) { event in
                Text(event.name)
                HStack{
                    NavigationLink(destination: EventDetailsView()){
                        Text("Go to Welcome")
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
