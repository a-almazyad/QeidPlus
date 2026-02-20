import Foundation

enum Winner: Codable, Equatable {
    case us
    case them
}

struct Match: Codable {
    var rounds: [Round] = []
    var targetScore: Int = GameConstants.targetScore

    var usTotal: Int {
        rounds.reduce(0) { $0 + $1.usFinal }
    }

    var themTotal: Int {
        rounds.reduce(0) { $0 + $1.themFinal }
    }

    var winner: Winner? {
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
