import Foundation

enum RoundMode: String, CaseIterable, Codable, Identifiable {
    case sun
    case hokom

    var id: String { rawValue }

    var base: Int {
        switch self {
        case .sun:   return GameConstants.sunBase
        case .hokom: return GameConstants.hokomBase
        }
    }

    var localizedKey: String {
        switch self {
        case .sun:   return "mode_sun"
        case .hokom: return "mode_hokom"
        }
    }
}
