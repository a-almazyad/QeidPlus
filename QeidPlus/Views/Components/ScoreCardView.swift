import SwiftUI

struct ScoreCardView: View {
    let teamKey: String   // localization key e.g. "team_us"
    let score: Int
    let hasWon: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(LocalizedStringKey(teamKey))
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(score)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(hasWon ? Color.green : Color.primary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35), value: score)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            hasWon ? Color.green : Color.clear,
                            lineWidth: 2.5
                        )
                )
        )
    }
}

#Preview {
    HStack {
        ScoreCardView(teamKey: "team_us", score: 98, hasWon: false)
        ScoreCardView(teamKey: "team_them", score: 120, hasWon: false)
    }
    .padding()
}
