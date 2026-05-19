//
//  EventCreatedAvailabilityPromptView.swift
//  planit
//

import SwiftUI

struct EventCreatedAvailabilityPromptView: View {
    var eventName: String
    var onRespondNow: (() -> Void)? = nil
    var onMaybeLater: (() -> Void)? = nil

    private var headline: String {
//        let trimmed = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
//        if trimmed.isEmpty {
            return "Your event is ready! Would you like to add your availability now?"
//        }
//        return "“\(trimmed)” is ready! Would you like to add your availability now?"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(headline)
                .multilineTextAlignment(.center)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 28)

            Button("Yes, let's add it!") {
                onRespondNow?()
            }
            .buttonStyle(PlanItPrimaryButtonStyle())

            Button(action: { onMaybeLater?() }) {
                Text("Maybe later...")
            }
            .buttonStyle(PlanItTextLinkButtonStyle())

            Spacer()
        }
        .planItScreen()
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        EventCreatedAvailabilityPromptView(eventName: "Sunday brunch")
    }
}
