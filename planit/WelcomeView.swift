//
//  WelcomeView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/6/26.
//

import SwiftUI

struct WelcomeView: View {
    @State private var username = "Kore" //TODO figure out how to access the real username
    var body: some View {
        Spacer()
        Text("Welcome, \(username)! Are you ready to plan your first event?")
            .multilineTextAlignment(.center)
            .font(.title)
            .bold()
            .padding(.horizontal)
            .foregroundStyle(Color.accent)
        Button("Let's do it!"){
            //TODO figure out page nav
        }
            .buttonStyle(.borderedProminent)
           .font(.title3)
           .padding(.bottom,5)
        Button("Maybe later..."){
            //TODO figure out page nav
        }
        Spacer()
    }
}

#Preview {
    WelcomeView()
}
