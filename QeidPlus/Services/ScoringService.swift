import Foundation

/// Pure scoring functions — no side effects, easy to unit-test.
enum ScoringService {

    static func baseAdjusted(mode: RoundMode, multiplier: MultiplierOption) -> Int {
        mode.base * multiplier.value
    }

    /// Double projects multiplies all projects by 2, EXCEPT Baloot which is always 2.
    /// Wikipedia: "In Double, Three and Four, Projects are calculated X2, X3, X4 respectively.
    /// (Except for 'Baloot', which is always 2)"
    static func projectPoints(projects: Set<ProjectType>, mode: RoundMode, doubled: Bool) -> Int {
        projects.reduce(0) { sum, project in
            let base = project.points(for: mode)
            let mult = (doubled && project != .baloot) ? GameConstants.doubleProjectsMultiplier : 1
            return sum + base * mult
        }
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
        themBase: Int,
        coffeeWinner: Winner?
    ) -> Round {
        let baseAdj = baseAdjusted(mode: mode, multiplier: multiplier)
        let pUs   = projectPoints(projects: projectsUs,   mode: mode, doubled: doubleProjects)
        let pThem = projectPoints(projects: projectsThem, mode: mode, doubled: doubleProjects)

        // For coffee rounds, winner takes all base points; loser gets 0.
        let finalUsBase: Int
        let finalThemBase: Int
        if multiplier == .coffee, let winner = coffeeWinner {
            finalUsBase   = (winner == .us)   ? baseAdj : 0
            finalThemBase = (winner == .them)  ? baseAdj : 0
        } else {
            finalUsBase   = usBase
            finalThemBase = themBase
        }

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
            usBase: finalUsBase,
            themBase: finalThemBase,
            baseAdjusted: baseAdj,
            projectsUs: pUs,
            projectsThem: pThem,
            usFinal: finalUsBase + pUs,
            themFinal: finalThemBase + pThem,
            coffeeWinner: coffeeWinner
        )
    }

    // MARK: - Self-tests (DEBUG only)
    static func runSelfTests() {
        assert(baseAdjusted(mode: .sun,   multiplier: .normal) == 26)
        assert(baseAdjusted(mode: .sun,   multiplier: .x2)     == 52)
        assert(baseAdjusted(mode: .hokom, multiplier: .coffee)  == 80)
        // Sira (Sara) values
        assert(projectPoints(projects: [.sara], mode: .sun,   doubled: false) == 4)
        assert(projectPoints(projects: [.sara], mode: .sun,   doubled: true)  == 8)
        assert(projectPoints(projects: [.sara], mode: .hokom, doubled: false) == 2)
        // 50 values
        assert(projectPoints(projects: [.p50],  mode: .sun,   doubled: false) == 10)
        assert(projectPoints(projects: [.p50],  mode: .hokom, doubled: false) == 5)
        // 100 values
        assert(projectPoints(projects: [.p100], mode: .sun,   doubled: false) == 20)
        assert(projectPoints(projects: [.p100], mode: .hokom, doubled: false) == 10)
        // 400 — Sun only
        assert(projectPoints(projects: [.p400], mode: .sun,   doubled: false) == 40)
        // Baloot — Hokom only, always 2 even when doubled
        assert(projectPoints(projects: [.baloot], mode: .hokom, doubled: false) == 2)
        assert(projectPoints(projects: [.baloot], mode: .hokom, doubled: true)  == 2)
        assert(projectPoints(projects: [.baloot], mode: .sun,   doubled: false) == 0)
        print("ScoringService: all self-tests passed ✓")
    }
}
