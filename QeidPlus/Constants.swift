import Foundation

// MARK: - Game Constants
// All scoring values are defined here for easy future edits.
enum GameConstants {
    static let sunBase: Int = 26
    static let hokomBase: Int = 16
    static let targetScore: Int = 152
    static let coffeeMultiplier: Int = 5

    // Projects — values differ by mode (Sun vs Hokom)
    static let projectSaraPointsSun: Int     = 4
    static let projectSaraPointsHokom: Int   = 2

    static let project50PointsSun: Int       = 10
    static let project50PointsHokom: Int     = 5

    static let project100PointsSun: Int      = 20
    static let project100PointsHokom: Int    = 10

    static let project400PointsSun: Int      = 40
    static let project400PointsHokom: Int    = 20

    /// Baloot only exists in Hokom
    static let projectBalootPointsHokom: Int = 2

    /// "Double Projects" always multiplies project points by 2
    static let doubleProjectsMultiplier: Int = 2

    // UX Behavior
    static let playSoundOnAddRound: Bool = true
}
