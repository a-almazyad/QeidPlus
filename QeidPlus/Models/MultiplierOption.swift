import Foundation

enum MultiplierOption: String, CaseIterable, Codable, Identifiable {
    case normal
    case x2
    case x3
    case x4
    case coffee

    var id: String { rawValue }

    var value: Int {
        switch self {
        case .normal: return 1
        case .x2:     return 2
        case .x3:     return 3
        case .x4:     return 4
        case .coffee: return GameConstants.coffeeMultiplier
        }
    }

    var localizedKey: String {
        switch self {
        case .normal: return "multiplier_normal"
        case .x2:     return "multiplier_x2"
        case .x3:     return "multiplier_x3"
        case .x4:     return "multiplier_x4"
        case .coffee: return "multiplier_coffee"
        }
    }
}
