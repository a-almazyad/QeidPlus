import Foundation

enum ProjectType: String, CaseIterable, Codable, Hashable, Identifiable {
    case sara
    case p50
    case p100
    case p400
    case baloot

    var id: String { rawValue }

    var points: Int {
        switch self {
        case .sara:   return GameConstants.projectSaraPoints
        case .p50:    return GameConstants.project50Points
        case .p100:   return GameConstants.project100Points
        case .p400:   return GameConstants.project400Points
        case .baloot: return GameConstants.projectBalootPoints
        }
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
