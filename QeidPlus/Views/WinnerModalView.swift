import SwiftUI

struct WinnerModalView: View {
    let winner: Winner
    let usTotal: Int
    let themTotal: Int
    let onReset: () -> Void
    let onDismiss: () -> Void

    @State private var showShare = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Trophy
            Image(systemName: "trophy.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.yellow)
                .shadow(color: .yellow.opacity(0.4), radius: 16)

            // Winner label
            VStack(spacing: 8) {
                Text(NSLocalizedString("winner_title", comment: ""))
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text(winnerText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
            }

            // Final scores
            HStack(spacing: 24) {
                scoreChip(labelKey: "team_us", value: usTotal, highlight: winner == .us)
                scoreChip(labelKey: "team_them", value: themTotal, highlight: winner == .them)
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button(action: {
                    HapticFeedback.impact()
                    onReset()
                }) {
                    Label(NSLocalizedString("reset_game", comment: ""), systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(action: { showShare = true }) {
                    Label(NSLocalizedString("share", comment: ""), systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(action: onDismiss) {
                    Text(NSLocalizedString("continue_playing", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [shareText])
                .presentationDetents([.medium])
        }
    }

    // MARK: - Private

    private var winnerText: String {
        switch winner {
        case .us:   return NSLocalizedString("winner_us", comment: "")
        case .them: return NSLocalizedString("winner_them", comment: "")
        }
    }

    private var shareText: String {
        String(
            format: NSLocalizedString("share_score_format", comment: ""),
            usTotal, themTotal
        )
    }

    private func scoreChip(labelKey: String, value: Int, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(labelKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? Color.green : Color.primary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(highlight ? Color.green : Color.clear, lineWidth: 2)
                )
        )
    }
}

#Preview {
    WinnerModalView(
        winner: .us, usTotal: 160, themTotal: 130,
        onReset: {}, onDismiss: {}
    )
}
