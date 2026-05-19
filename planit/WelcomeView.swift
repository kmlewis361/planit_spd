//
//  WelcomeView.swift
//  planit
//
//  Created by Elise Wong-McBride on 3/6/26.
//

import SwiftUI

struct WelcomeView: View {
    var onDoIt: (() -> Void)? = nil
    var onMaybeLater: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Welcome, \(globalUsername)! Are you ready to plan your first event?")
                .multilineTextAlignment(.center)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 28)

            Button("Let's do it!") {
                onDoIt?()
            }
            .buttonStyle(PlanItPrimaryButtonStyle())
            .padding(.horizontal, 28)

            Button(action: { onMaybeLater?() }) {
                Text("Maybe later...")
            }
            .buttonStyle(PlanItTextLinkButtonStyle())

            Spacer()
        }
        .planItScreen()
    }
}

#Preview {
    WelcomeView()
}
