import SwiftUI

struct RoundRowView: View {
    let round: Round

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top line: round number + mode badge + multiplier
            HStack(spacing: 8) {
                Text(String(format: NSLocalizedString("round_number", comment: ""), round.index))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                modeBadge
                multiplierBadge
                Spacer()
            }

            // Middle line: projects summary (only if any selected)
            if !round.selectedProjectsUs.isEmpty || !round.selectedProjectsThem.isEmpty {
                Text(projectsSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Bottom line: final points
            HStack {
                Text(
                    String(
                        format: NSLocalizedString("round_score_format", comment: ""),
                        round.usFinal,
                        round.themFinal
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.primary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Private

    private var modeBadge: some View {
        Text(LocalizedStringKey(round.mode.localizedKey))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(round.mode == .sun ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2)))
            .foregroundStyle(round.mode == .sun ? Color.orange : Color.blue)
    }

    private var multiplierBadge: some View {
        Text(LocalizedStringKey(round.multiplierOption.localizedKey))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var projectsSummary: String {
        var parts: [String] = []
        if !round.selectedProjectsUs.isEmpty {
            let us = round.selectedProjectsUs
                .sorted { $0.rawValue < $1.rawValue }
                .map { NSLocalizedString($0.localizedKey, comment: "") }
                .joined(separator: "+")
            parts.append(String(format: NSLocalizedString("projects_us_label", comment: ""), us))
        }
        if !round.selectedProjectsThem.isEmpty {
            let them = round.selectedProjectsThem
                .sorted { $0.rawValue < $1.rawValue }
                .map { NSLocalizedString($0.localizedKey, comment: "") }
                .joined(separator: "+")
            parts.append(String(format: NSLocalizedString("projects_them_label", comment: ""), them))
        }
        return parts.joined(separator: " | ")
    }
}
