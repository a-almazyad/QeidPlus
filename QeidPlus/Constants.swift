import Foundation

// MARK: - Game Constants
// All scoring values are defined here for easy future edits.
enum GameConstants {
    static let sunBase: Int = 26
    static let hokomBase: Int = 16
    static let targetScore: Int = 152
    static let coffeeMultiplier: Int = 5

    // Project point values
    static let projectSaraPoints: Int = 0
    static let project50Points: Int = 50
    static let project100Points: Int = 100
    static let project400Points: Int = 400
    static let projectBalootPoints: Int = 20

    // UX Behavior
    static let playSoundOnAddRound: Bool = true

    /// Controls how projects are multiplied when "Double Projects" is ON.
    /// .sameAsHand  → multiply by the same hand multiplier (x2/x3/x4/coffee)  [Option A]
    /// .alwaysTwo   → always multiply by 2                                      [Option B]
    static let projectMultiplierMode: ProjectMultiplierMode = .sameAsHand
}

enum ProjectMultiplierMode {
    case sameAsHand
    case alwaysTwo
}
