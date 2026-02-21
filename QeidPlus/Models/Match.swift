import Foundation

enum Winner: Codable, Equatable {
    case us
    case them
}

struct Match: Codable {
    var rounds: [Round] = []
    var targetScore: Int = GameConstants.targetScore

    /// Extra points added to the Coffee/Qahwah winning team so their
    /// total reaches exactly `targetScore` (triggering the win screen).
    /// Reset to zero whenever a coffee round is undone or deleted.
    var coffeeTopUpUs: Int = 0
    var coffeeTopUpThem: Int = 0

    var usTotal: Int {
        rounds.reduce(0) { $0 + $1.usFinal } + coffeeTopUpUs
    }

    var themTotal: Int {
        rounds.reduce(0) { $0 + $1.themFinal } + coffeeTopUpThem
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

    /// Called after a Coffee win: tops up the winning team's running total
    /// to `targetScore` by adding the exact delta needed.
    mutating func topUpToTarget(winner: Winner) {
        // Start fresh — only one coffee top-up is active at a time.
        coffeeTopUpUs   = 0
        coffeeTopUpThem = 0
        let rawUs   = rounds.reduce(0) { $0 + $1.usFinal }
        let rawThem = rounds.reduce(0) { $0 + $1.themFinal }
        switch winner {
        case .us:
            let needed = max(0, targetScore - rawUs)
            coffeeTopUpUs = needed
        case .them:
            let needed = max(0, targetScore - rawThem)
            coffeeTopUpThem = needed
        }
    }

    /// Called after undo/delete to recompute (or clear) the coffee top-up
    /// based on whichever coffee round (if any) is still the last round.
    mutating func recalculateCoffeeTopUp() {
        coffeeTopUpUs   = 0
        coffeeTopUpThem = 0
        if let lastCoffee = rounds.last(where: {
            $0.multiplierOption == .coffee && $0.coffeeWinner != nil
        }), let winner = lastCoffee.coffeeWinner {
            topUpToTarget(winner: winner)
        }
    }
}
