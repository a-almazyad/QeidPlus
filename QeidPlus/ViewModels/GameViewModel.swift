import Foundation
import Combine

@MainActor
final class GameViewModel: ObservableObject {

    @Published var match: Match = Match()
    @Published var showWinner: Bool = false

    /// Rounds removed by undo, available to restore via redo.
    /// Cleared whenever a new round is added.
    private var redoStack: [Round] = []

    private let saveURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("current_match.json")
    }()

    init() {
        loadFromDisk()
        #if DEBUG
        ScoringService.runSelfTests()
        #endif
    }

    // MARK: - Public API

    func addRound(_ round: Round) {
        var r = round
        r.index = match.rounds.count + 1
        match.rounds.append(r)
        // New round invalidates the redo history.
        redoStack.removeAll()

        // Item 1: Coffee/Qahwah — winning team's score is topped up to 152
        // (the target), then the normal winner check fires and ends the game.
        if r.multiplierOption == .coffee, let coffeeWinner = r.coffeeWinner {
            match.topUpToTarget(winner: coffeeWinner)
        }

        saveToDisk()
        if match.winner != nil {
            showWinner = true
            AppRatingManager.shared.recordGameCompleted()
        }
    }

    func deleteRound(id: UUID) {
        match.rounds.removeAll { $0.id == id }
        match.recalculateCoffeeTopUp()
        reindex()
        saveToDisk()
    }

    func undoLastRound() {
        guard !match.rounds.isEmpty else { return }
        let last = match.rounds.removeLast()
        redoStack.append(last)
        match.recalculateCoffeeTopUp()
        saveToDisk()
    }

    func redoLastRound() {
        guard !redoStack.isEmpty else { return }
        var r = redoStack.removeLast()
        r.index = match.rounds.count + 1
        match.rounds.append(r)
        // Re-apply top-up if the re-done round was a coffee win.
        if r.multiplierOption == .coffee, let coffeeWinner = r.coffeeWinner {
            match.topUpToTarget(winner: coffeeWinner)
        }
        saveToDisk()
        if match.winner != nil {
            showWinner = true
        }
    }

    var canUndo: Bool { !match.rounds.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func resetGame() {
        match = Match()
        redoStack.removeAll()
        showWinner = false
        saveToDisk()
    }

    func dismissWinner() {
        showWinner = false
    }

    var shareText: String {
        let us   = match.usTotal
        let them = match.themTotal
        return String(
            format: NSLocalizedString("share_score_format", comment: ""),
            us, them
        )
    }

    // MARK: - Private

    private func reindex() {
        for i in match.rounds.indices {
            match.rounds[i].index = i + 1
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(match)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("GameViewModel: save failed — \(error)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let data = try Data(contentsOf: saveURL)
            match = try JSONDecoder().decode(Match.self, from: data)
        } catch {
            print("GameViewModel: load failed — \(error)")
            match = Match()
        }
    }
}
