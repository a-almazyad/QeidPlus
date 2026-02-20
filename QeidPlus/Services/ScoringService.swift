import Foundation

/// Pure scoring functions — no side effects, easy to unit-test.
enum ScoringService {

    static func baseAdjusted(mode: RoundMode, multiplier: MultiplierOption) -> Int {
        mode.base * multiplier.value
    }

    static func projectMultiplierValue(for option: MultiplierOption, doubleProjects: Bool) -> Int {
        guard doubleProjects else { return 1 }
        switch GameConstants.projectMultiplierMode {
        case .sameAsHand: return option.value
        case .alwaysTwo:  return 2
        }
    }

    static func projectPoints(projects: Set<ProjectType>, multiplier: Int) -> Int {
        projects.reduce(0) { $0 + $1.points } * multiplier
    }

    static func buildRound(
        index: Int,
        mode: RoundMode,
        multiplier: MultiplierOption,
        autoComplete: Bool,
        doubleProjects: Bool,
        projectsUs: Set<ProjectType>,
        projectsThem: Set<ProjectType>,
        usBase: Int,
        themBase: Int
    ) -> Round {
        let baseAdj = baseAdjusted(mode: mode, multiplier: multiplier)
        let projMult = projectMultiplierValue(for: multiplier, doubleProjects: doubleProjects)
        let pUs   = projectPoints(projects: projectsUs,   multiplier: projMult)
        let pThem = projectPoints(projects: projectsThem, multiplier: projMult)

        return Round(
            id: UUID(),
            index: index,
            dateCreated: Date(),
            mode: mode,
            multiplierOption: multiplier,
            autoCompleteEnabled: autoComplete,
            doubleProjectsEnabled: doubleProjects,
            selectedProjectsUs: projectsUs,
            selectedProjectsThem: projectsThem,
            usBase: usBase,
            themBase: themBase,
            baseAdjusted: baseAdj,
            projectsUs: pUs,
            projectsThem: pThem,
            usFinal: usBase + pUs,
            themFinal: themBase + pThem
        )
    }

    // MARK: - Inline verification (debug only)
    static func runSelfTests() {
        // صن × عادي → 26
        assert(baseAdjusted(mode: .sun, multiplier: .normal) == 26)
        // صن × دبل → 52
        assert(baseAdjusted(mode: .sun, multiplier: .x2) == 52)
        // حكم × قهوة → 16 × 5 = 80
        assert(baseAdjusted(mode: .hokom, multiplier: .coffee) == 80)
        // project 50 + baloot (20) = 70
        assert(projectPoints(projects: [.p50, .baloot], multiplier: 1) == 70)
        print("ScoringService: all self-tests passed ✓")
    }
}
