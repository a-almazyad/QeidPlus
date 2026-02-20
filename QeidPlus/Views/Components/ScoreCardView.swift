import SwiftUI

struct ScoreCardView: View {
    let teamKey: String   // localization key e.g. "team_us"
    let score: Int
    let isLeading: Bool   // true if this team has the higher score
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
                            hasWon ? Color.green : (isLeading ? Color.accentColor.opacity(0.5) : Color.clear),
                            lineWidth: hasWon ? 2.5 : 1.5
                        )
                )
        )
    }
}

#Preview {
    HStack {
        ScoreCardView(teamKey: "team_us", score: 98, isLeading: true, hasWon: false)
        ScoreCardView(teamKey: "team_them", score: 120, isLeading: false, hasWon: false)
    }
    .padding()
}
