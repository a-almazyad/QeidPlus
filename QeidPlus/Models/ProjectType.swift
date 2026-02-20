import Foundation

enum ProjectType: String, CaseIterable, Codable, Hashable, Identifiable {
    case sara
    case p50
    case p100
    case p400
    case baloot

    var id: String { rawValue }

    /// Points are mode-dependent. Baloot returns 0 in Sun (only available in Hokom).
    func points(for mode: RoundMode) -> Int {
        switch (self, mode) {
        case (.sara,   .sun):   return GameConstants.projectSaraPointsSun
        case (.sara,   .hokom): return GameConstants.projectSaraPointsHokom
        case (.p50,    .sun):   return GameConstants.project50PointsSun
        case (.p50,    .hokom): return GameConstants.project50PointsHokom
        case (.p100,   .sun):   return GameConstants.project100PointsSun
        case (.p100,   .hokom): return GameConstants.project100PointsHokom
        case (.p400,   .sun):   return GameConstants.project400PointsSun
        case (.p400,   .hokom): return GameConstants.project400PointsHokom
        case (.baloot, .hokom): return GameConstants.projectBalootPointsHokom
        case (.baloot, .sun):   return 0   // Baloot not available in Sun
        }
    }

    /// Baloot is only valid in Hokom.
    func isAvailable(in mode: RoundMode) -> Bool {
        if self == .baloot && mode == .sun { return false }
        return true
    }

    var localizedKey: String {
        switch self {
        case .sara:   return "project_sara"
        case .p50:    return "project_50"
        case .p100:   return "project_100"
        case .p400:   return "project_400"
        case .baloot: return "project_baloot"
        }
    }
}
