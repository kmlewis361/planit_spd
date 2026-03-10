//
//  ContentView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/6/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selection: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("PlanIt")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                NavigationLink(destination: LoginView()) {
                    Text("Go to Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                NavigationLink(destination: WelcomeView()) {
                    Text("Go to Welcome")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
//            .navigationTitle("Home")
        }
    }
}

#Preview {
    ContentView()
}
