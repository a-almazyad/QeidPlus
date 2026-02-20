import Foundation

struct Round: Identifiable, Codable, Equatable {
    let id: UUID
    var index: Int
    let dateCreated: Date

    // User selections
    var mode: RoundMode
    var multiplierOption: MultiplierOption
    var autoCompleteEnabled: Bool
    var doubleProjectsEnabled: Bool
    var selectedProjectsUs: Set<ProjectType>
    var selectedProjectsThem: Set<ProjectType>

    // Entered base points
    var usBase: Int
    var themBase: Int

    // Pre-computed values (stored for display without re-computing)
    var baseAdjusted: Int
    var projectsUs: Int
    var projectsThem: Int
    var usFinal: Int
    var themFinal: Int

    /// Non-nil when multiplierOption == .coffee. Indicates which team won the coffee.
    /// Defaults to nil for backwards-compatibility when decoding old saved games.
    var coffeeWinner: Winner?
}
