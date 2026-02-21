import Foundation

/// Tracks which side the user last edited to prevent auto-complete loops.
enum EditedSide { case us, them, none }

@MainActor
final class AddRoundViewModel: ObservableObject {

    // MARK: - User Inputs
    @Published var mode: RoundMode = .sun {
        didSet { onModeChanged() }
    }
    @Published var multiplier: MultiplierOption = .normal {
        didSet { onModeOrMultiplierChanged() }
    }
    @Published var autoCompleteEnabled: Bool = true
    @Published var doubleProjectsEnabled: Bool = false
    @Published var usBaseText: String = ""
    @Published var themBaseText: String = ""
    @Published var selectedProjectsUs: Set<ProjectType> = []
    @Published var selectedProjectsThem: Set<ProjectType> = []

    /// Only relevant when multiplier == .coffee
    @Published var coffeeWinner: Winner? = nil

    // MARK: - Internal State
    private(set) var lastEditedSide: EditedSide = .none

    // MARK: - Computed Scoring

    var isCoffeeRound: Bool { multiplier == .coffee }

    var baseAdjusted: Int {
        ScoringService.baseAdjusted(mode: mode, multiplier: multiplier)
    }

    /// Projects available for current mode (Baloot excluded in Sun).
    var availableProjects: [ProjectType] {
        ProjectType.allCases.filter { $0.isAvailable(in: mode) }
    }

    var computedProjectsUs: Int {
        ScoringService.projectPoints(projects: selectedProjectsUs, mode: mode, doubled: doubleProjectsEnabled)
    }

    var computedProjectsThem: Int {
        ScoringService.projectPoints(projects: selectedProjectsThem, mode: mode, doubled: doubleProjectsEnabled)
    }

    var usBaseValue: Int {
        if isCoffeeRound { return coffeeWinner == .us ? baseAdjusted : 0 }
        return Int(usBaseText) ?? 0
    }

    var themBaseValue: Int {
        if isCoffeeRound { return coffeeWinner == .them ? baseAdjusted : 0 }
        return Int(themBaseText) ?? 0
    }

    var usFinal: Int   { usBaseValue   + computedProjectsUs   }
    var themFinal: Int { themBaseValue + computedProjectsThem }

    // MARK: - Validation

    var validationError: String? {
        if isCoffeeRound { return nil }
        let adj = baseAdjusted
        if autoCompleteEnabled {
            if lastEditedSide == .us || lastEditedSide == .none {
                if usBaseValue < 0 || usBaseValue > adj {
                    return String(format: NSLocalizedString("validation_base_range", comment: ""), adj)
                }
            } else {
                if themBaseValue < 0 || themBaseValue > adj {
                    return String(format: NSLocalizedString("validation_base_range", comment: ""), adj)
                }
            }
        } else {
            if usBaseValue < 0 || usBaseValue > adj {
                return String(format: NSLocalizedString("validation_base_range", comment: ""), adj)
            }
            if themBaseValue < 0 || themBaseValue > adj {
                return String(format: NSLocalizedString("validation_base_range", comment: ""), adj)
            }
        }
        return nil
    }

    var sumsMatchWarning: Bool {
        guard !autoCompleteEnabled, !isCoffeeRound else { return false }
        return usBaseValue + themBaseValue != baseAdjusted
    }

    var isValid: Bool {
        if isCoffeeRound { return coffeeWinner != nil }
        return validationError == nil && !usBaseText.isEmpty && !themBaseText.isEmpty
    }

    // MARK: - Project Toggle

    func toggleProjectUs(_ project: ProjectType) {
        guard project.isAvailable(in: mode) else { return }
        if selectedProjectsUs.contains(project) {
            selectedProjectsUs.remove(project)
        } else {
            // Mutual exclusion: if the other team already has this project,
            // they lose it — EXCEPT Baloot in Hokom (both teams may hold it).
            let balootException = project == .baloot && mode == .hokom
            if !balootException {
                selectedProjectsThem.remove(project)
            }
            selectedProjectsUs.insert(project)
        }
    }

    func toggleProjectThem(_ project: ProjectType) {
        guard project.isAvailable(in: mode) else { return }
        if selectedProjectsThem.contains(project) {
            selectedProjectsThem.remove(project)
        } else {
            // Mutual exclusion: if our team already has this project,
            // we lose it — EXCEPT Baloot in Hokom (both teams may hold it).
            let balootException = project == .baloot && mode == .hokom
            if !balootException {
                selectedProjectsUs.remove(project)
            }
            selectedProjectsThem.insert(project)
        }
    }

    // MARK: - Build Round

    func buildRound(index: Int) -> Round {
        ScoringService.buildRound(
            index: index,
            mode: mode,
            multiplier: multiplier,
            autoComplete: autoCompleteEnabled,
            doubleProjects: doubleProjectsEnabled,
            projectsUs: selectedProjectsUs,
            projectsThem: selectedProjectsThem,
            usBase: usBaseValue,
            themBase: themBaseValue,
            coffeeWinner: isCoffeeRound ? coffeeWinner : nil
        )
    }

    // MARK: - Field Edit Handlers

    func userEditedUsBase(_ text: String) {
        lastEditedSide = .us
        usBaseText = text
        if autoCompleteEnabled { computeThemFromUs() }
    }

    func userEditedThemBase(_ text: String) {
        lastEditedSide = .them
        themBaseText = text
        if autoCompleteEnabled { computeUsFromThem() }
    }

    func onAutoCompleteToggled() {
        guard autoCompleteEnabled else { return }
        if lastEditedSide == .us        { computeThemFromUs()  }
        else if lastEditedSide == .them { computeUsFromThem()  }
    }

    // MARK: - Private Helpers

    private func onModeChanged() {
        // Remove Baloot if switching to Sun (not available in Sun)
        if mode == .sun {
            selectedProjectsUs.remove(.baloot)
            selectedProjectsThem.remove(.baloot)
        }
        onModeOrMultiplierChanged()
    }

    func onModeOrMultiplierChanged() {
        guard autoCompleteEnabled, !isCoffeeRound else { return }
        if lastEditedSide == .us        { computeThemFromUs()  }
        else if lastEditedSide == .them { computeUsFromThem()  }
    }

    private func computeThemFromUs() {
        let usVal = Int(usBaseText) ?? 0
        let computed = baseAdjusted - usVal
        themBaseText = computed >= 0 ? String(computed) : ""
    }

    private func computeUsFromThem() {
        let themVal = Int(themBaseText) ?? 0
        let computed = baseAdjusted - themVal
        usBaseText = computed >= 0 ? String(computed) : ""
    }
}
