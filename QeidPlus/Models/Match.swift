import Foundation

enum Winner: Codable, Equatable {
    case us
    case them
}

struct Match: Codable {
    var rounds: [Round] = []
    var targetScore: Int = GameConstants.targetScore

    /// When set, overrides the score-based winner calculation.
    /// Used for Coffee/Qahwah instant-win: the game ends immediately
    /// regardless of the current total scores.
    var instantWinner: Winner? = nil

    var usTotal: Int {
        rounds.reduce(0) { $0 + $1.usFinal }
    }

    var themTotal: Int {
        rounds.reduce(0) { $0 + $1.themFinal }
    }

    var winner: Winner? {
        // Coffee instant win takes priority over score threshold.
        if let instant = instantWinner { return instant }
        let usWon = usTotal >= targetScore
        let themWon = themTotal >= targetScore
        if usWon && themWon {
            return usTotal >= themTotal ? .us : .them
        }
        if usWon   { return .us }
        if themWon { return .them }
        return nil
    }
}
