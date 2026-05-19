//
//  BestTimeAvailabilityViews.swift
//  planit
//

import SwiftUI

struct BestTimeWindowCard: View {
    let timeLabel: String
    let fullyAvailableCount: Int
    let inviteeRows: [InviteeAvailabilityRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeLabel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("\(fullyAvailableCount) fully available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.35)

            ForEach(inviteeRows) { row in
                InviteeAvailabilityLine(
                    displayName: planItDisplayHandle(row.invitee),
                    status: row.status
                )
            }
        }
        .planItCard()
    }

    private func planItDisplayHandle(_ raw: String) -> String {
        let normalized = normalizedPlanItUsername(raw)
        guard !normalized.isEmpty else { return raw }
        return normalized.hasPrefix("@") ? normalized : "@\(normalized)"
    }
}

private struct InviteeAvailabilityLine: View {
    let displayName: String
    let status: InviteeAvailabilityStatus

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(nameColor)
                .lineLimit(1)

            Spacer(minLength: 12)

            if let trailing = trailingAnnotation {
                Text(trailing.text)
                    .font(.caption)
                    .foregroundStyle(trailing.color)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
    }

    private var trailingAnnotation: (text: String, color: Color)? {
        switch status {
        case .notResponded:
            return ("No response yet", PlanItTheme.availabilityNoResponse)
        case .partiallyFree(let summary):
            return (summary, PlanItTheme.availabilityPartial)
        case .fullyFree, .notFree:
            return nil
        }
    }

    private var nameColor: Color {
        switch status {
        case .notResponded:
            return PlanItTheme.availabilityNoResponse
        case .fullyFree:
            return PlanItTheme.availabilityFull
        case .notFree:
            return PlanItTheme.availabilityUnavailable
        case .partiallyFree:
            return PlanItTheme.availabilityPartial
        }
    }
}
