//
//  WelcomeView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/6/26.
//

import SwiftUI

struct WelcomeView: View {
    var onMaybeLater: (() -> Void)? = nil

    var body: some View {
        VStack {
            Spacer()
            Text("Welcome, \(globalUsername)! Are you ready to plan your first event?")
                .multilineTextAlignment(.center)
                .font(.title)
                .bold()
                .padding(.horizontal)
                .foregroundStyle(Color.accentColor)
            Button("Let's do it!"){
                //TODO figure out page nav
                print("WelcomeView: Let's do it tapped")
            }
                .buttonStyle(.borderedProminent)
               .font(.title3)
               .padding(.bottom,5)
            Button(action: {
                // Use the provided closure to let the parent decide navigation
                print("User chose maybe later (WelcomeView)")
                onMaybeLater?()
            }) {
                Text("Maybe later...")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
            }
            Spacer()
        }
    }
}

#Preview {
    WelcomeView()
}
