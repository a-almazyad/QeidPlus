import SwiftUI

struct RoundRowView: View {
    let round: Round

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left: round info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(String(format: NSLocalizedString("round_number", comment: ""), round.index))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    modeBadge
                    multiplierBadge
                }

                if !round.selectedProjectsUs.isEmpty || !round.selectedProjectsThem.isEmpty {
                    Text(projectsSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right: final scores
            HStack(spacing: 16) {
                scoreColumn(label: NSLocalizedString("team_us", comment: ""), value: round.usFinal)
                scoreColumn(label: NSLocalizedString("team_them", comment: ""), value: round.themFinal)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Private

    private func scoreColumn(label: String, value: Int) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(minWidth: 36)
    }

    private var modeBadge: some View {
        Text(LocalizedStringKey(round.mode.localizedKey))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(round.mode == .sun ? Color.orange.opacity(0.18) : Color.blue.opacity(0.18)))
            .foregroundStyle(round.mode == .sun ? Color.orange : Color.blue)
    }

    private var multiplierBadge: some View {
        Group {
            if round.multiplierOption != .normal {
                Text(LocalizedStringKey(round.multiplierOption.localizedKey))
                    .font(.caption)
                    .foregroundStyle(round.multiplierOption == .coffee ? Color.brown : .secondary)
            }
        }
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
