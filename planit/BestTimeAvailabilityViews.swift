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
        VStack(alignment: .leading, spacing: 2) {
            Text(displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(nameColor)

            if case .partiallyFree(let summary) = status {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(PlanItTheme.availabilityPartial)
            } else if case .notResponded = status {
                Text("No response yet")
                    .font(.caption)
                    .foregroundStyle(PlanItTheme.availabilityNoResponse)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
