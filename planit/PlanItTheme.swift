//
//  PlanItTheme.swift
//  planit
//

import SwiftUI

enum PlanItTheme {
    static let fieldCornerRadius: CGFloat = 10
    static let cardCornerRadius: CGFloat = 12
    static let fieldBackground = Color("FieldBackground")

    /// Invitee fully available for the entire best-time window.
    static let availabilityFull = Color.accentColor
    /// Invitee selected some but not all slots in the window.
    static let availabilityPartial = Color.accentColor.opacity(0.55)
    /// Invitee responded but is not free for the full window.
    static let availabilityUnavailable = Color.red
    /// Invitee has not submitted a response yet.
    static let availabilityNoResponse = Color.secondary
}

// MARK: - Buttons

struct PlanItPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(Capsule())
    }
}

struct PlanItSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(PlanItTheme.fieldBackground)
            .clipShape(Capsule())
    }
}

struct PlanItTextLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(.primary)
            .underline(configuration.isPressed)
    }
}

// MARK: - View modifiers

private struct PlanItFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PlanItTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: PlanItTheme.fieldCornerRadius, style: .continuous))
    }
}

private struct PlanItCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PlanItTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: PlanItTheme.cardCornerRadius, style: .continuous))
    }
}

private struct PlanItErrorBannerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PlanItTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: PlanItTheme.fieldCornerRadius, style: .continuous))
    }
}

extension View {
    func planItScreen() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
    }

    func planItField() -> some View {
        modifier(PlanItFieldModifier())
    }

    func planItCard() -> some View {
        modifier(PlanItCardModifier())
    }

    func planItErrorBanner() -> some View {
        modifier(PlanItErrorBannerModifier())
    }
}

extension Text {
    func planItScreenTitle() -> some View {
        font(.largeTitle.weight(.semibold))
            .foregroundStyle(Color.accentColor)
    }

    func planItSectionTitle() -> some View {
        font(.headline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func planItBodyOnCard() -> some View {
        font(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
