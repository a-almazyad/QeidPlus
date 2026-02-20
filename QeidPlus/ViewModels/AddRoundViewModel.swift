import Foundation
import Combine

/// Tracks which side the user last edited to prevent auto-complete loops.
enum EditedSide { case us, them, none }

@MainActor
final class AddRoundViewModel: ObservableObject {

    // MARK: - User Inputs
    @Published var mode: RoundMode = .sun
    @Published var multiplier: MultiplierOption = .normal
    @Published var autoCompleteEnabled: Bool = true
    @Published var doubleProjectsEnabled: Bool = false
    @Published var usBaseText: String = ""
    @Published var themBaseText: String = ""
    @Published var selectedProjectsUs: Set<ProjectType> = []
    @Published var selectedProjectsThem: Set<ProjectType> = []

    // MARK: - Internal State
    private var lastEditedSide: EditedSide = .none
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupAutoComplete()
    }

    // MARK: - Computed Scoring

    var baseAdjusted: Int {
        ScoringService.baseAdjusted(mode: mode, multiplier: multiplier)
    }

    var projectMultiplierValue: Int {
        ScoringService.projectMultiplierValue(for: multiplier, doubleProjects: doubleProjectsEnabled)
    }

    var computedProjectsUs: Int {
        ScoringService.projectPoints(projects: selectedProjectsUs, multiplier: projectMultiplierValue)
    }

    var computedProjectsThem: Int {
        ScoringService.projectPoints(projects: selectedProjectsThem, multiplier: projectMultiplierValue)
    }

    var usBaseValue: Int { Int(usBaseText) ?? 0 }
    var themBaseValue: Int { Int(themBaseText) ?? 0 }

    var usFinal: Int { usBaseValue + computedProjectsUs }
    var themFinal: Int { themBaseValue + computedProjectsThem }

    // MARK: - Validation

    var validationError: String? {
        let adj = baseAdjusted
        if autoCompleteEnabled {
            // Only validate the manually-entered side
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
        guard !autoCompleteEnabled else { return false }
        let adj = baseAdjusted
        return usBaseValue + themBaseValue != adj
    }

    var isValid: Bool {
        validationError == nil && !usBaseText.isEmpty && !themBaseText.isEmpty
    }

    // MARK: - Project Toggle

    func toggleProjectUs(_ project: ProjectType) {
        if selectedProjectsUs.contains(project) {
            selectedProjectsUs.remove(project)
        } else {
            selectedProjectsUs.insert(project)
        }
    }

    func toggleProjectThem(_ project: ProjectType) {
        if selectedProjectsThem.contains(project) {
            selectedProjectsThem.remove(project)
        } else {
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
            themBase: themBaseValue
        )
    }

    // MARK: - Field Edit Handlers (called from View)

    func userEditedUsBase(_ text: String) {
        lastEditedSide = .us
        usBaseText = text
        if autoCompleteEnabled {
            computeThemFromUs()
        }
    }

    func userEditedThemBase(_ text: String) {
        lastEditedSide = .them
        themBaseText = text
        if autoCompleteEnabled {
            computeUsFromThem()
        }
    }

    func onAutoCompleteToggled() {
        // Reset the computed side when toggling
        if autoCompleteEnabled {
            if lastEditedSide == .us {
                computeThemFromUs()
            } else if lastEditedSide == .them {
                computeUsFromThem()
            }
        }
    }

    func onModeOrMultiplierChanged() {
        // Re-run auto-complete after mode/multiplier changes
        guard autoCompleteEnabled else { return }
        if lastEditedSide == .us {
            computeThemFromUs()
        } else if lastEditedSide == .them {
            computeUsFromThem()
        }
    }

    // MARK: - Private Auto-Complete

    private func setupAutoComplete() {
        // No Combine-based auto-wiring needed; view calls handlers directly
    }

    private func computeThemFromUs() {
        guard autoCompleteEnabled else { return }
        let usVal = Int(usBaseText) ?? 0
        let computed = baseAdjusted - usVal
        if computed >= 0 {
            themBaseText = String(computed)
        } else {
            themBaseText = ""
        }
    }

    private func computeUsFromThem() {
        guard autoCompleteEnabled else { return }
        let themVal = Int(themBaseText) ?? 0
        let computed = baseAdjusted - themVal
        if computed >= 0 {
            usBaseText = String(computed)
        } else {
            usBaseText = ""
        }
    }
}
