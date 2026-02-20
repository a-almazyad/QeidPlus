import Foundation
import Combine

@MainActor
final class GameViewModel: ObservableObject {

    @Published var match: Match = Match()
    @Published var showWinner: Bool = false

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
        saveToDisk()
        if match.winner != nil {
            showWinner = true
        }
    }

    func deleteRound(id: UUID) {
        match.rounds.removeAll { $0.id == id }
        reindex()
        saveToDisk()
    }

    func undoLastRound() {
        guard !match.rounds.isEmpty else { return }
        match.rounds.removeLast()
        saveToDisk()
    }

    func resetGame() {
        match = Match()
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
