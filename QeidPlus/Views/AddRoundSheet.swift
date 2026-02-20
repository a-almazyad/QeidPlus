import SwiftUI
import AudioToolbox

struct AddRoundSheet: View {
    @ObservedObject var gameVM: GameViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = AddRoundViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // A) Mode selector
                Section {
                    Picker(NSLocalizedString("mode_label", comment: ""), selection: $vm.mode) {
                        ForEach(RoundMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.localizedKey)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.mode) { vm.onModeOrMultiplierChanged() }
                } header: {
                    Text(LocalizedStringKey("mode_label"))
                }

                // B) Calculation option
                Section {
                    Picker(NSLocalizedString("multiplier_label", comment: ""), selection: $vm.multiplier) {
                        ForEach(MultiplierOption.allCases) { opt in
                            Text(LocalizedStringKey(opt.localizedKey)).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.multiplier) { vm.onModeOrMultiplierChanged() }
                } header: {
                    Text(LocalizedStringKey("multiplier_label"))
                }

                // C) Auto-complete toggle
                Section {
                    Toggle(LocalizedStringKey("autocomplete_toggle"), isOn: $vm.autoCompleteEnabled)
                        .onChange(of: vm.autoCompleteEnabled) { vm.onAutoCompleteToggled() }
                }

                // D) Base points entry
                Section {
                    HStack {
                        Text(LocalizedStringKey("base_us"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", text: Binding(
                            get: { vm.usBaseText },
                            set: { vm.userEditedUsBase($0) }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                    }

                    HStack {
                        Text(LocalizedStringKey("base_them"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", text: Binding(
                            get: { vm.themBaseText },
                            set: { vm.userEditedThemBase($0) }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .disabled(vm.autoCompleteEnabled && vm.lastEditedSideIsUs)
                    }

                    if let error = vm.validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if vm.sumsMatchWarning {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(LocalizedStringKey("warning_sums_mismatch"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(
                        String(
                            format: NSLocalizedString("base_section_header", comment: ""),
                            vm.baseAdjusted
                        )
                    )
                }

                // E) Projects
                Section {
                    Toggle(LocalizedStringKey("double_projects_toggle"), isOn: $vm.doubleProjectsEnabled)
                } header: {
                    Text(LocalizedStringKey("projects_label"))
                }

                // Projects for Us
                Section {
                    projectsGrid(
                        projects: ProjectType.allCases,
                        selected: vm.selectedProjectsUs,
                        toggle: vm.toggleProjectUs
                    )
                } header: {
                    Text(LocalizedStringKey("projects_us_header"))
                }

                // Projects for Them
                Section {
                    projectsGrid(
                        projects: ProjectType.allCases,
                        selected: vm.selectedProjectsThem,
                        toggle: vm.toggleProjectThem
                    )
                } header: {
                    Text(LocalizedStringKey("projects_them_header"))
                }

                // F) Live Summary
                Section {
                    summaryRow(key: "summary_base_adjusted", value: vm.baseAdjusted)
                    summaryRow(key: "summary_projects_us", value: vm.computedProjectsUs)
                    summaryRow(key: "summary_projects_them", value: vm.computedProjectsThem)
                    Divider()
                    summaryRow(key: "summary_final_us", value: vm.usFinal, bold: true)
                    summaryRow(key: "summary_final_them", value: vm.themFinal, bold: true)
                } header: {
                    Text(LocalizedStringKey("summary_label"))
                }
            }
            .navigationTitle(LocalizedStringKey("add_round"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("add", comment: "")) {
                        addRound()
                    }
                    .fontWeight(.semibold)
                    .disabled(!vm.isValid)
                }
            }
        }
    }

    // MARK: - Private

    private func addRound() {
        let round = vm.buildRound(index: gameVM.match.rounds.count + 1)
        gameVM.addRound(round)
        HapticFeedback.impact(.medium)
        if GameConstants.playSoundOnAddRound {
            AudioServicesPlaySystemSound(1104)
        }
        dismiss()
    }

    @ViewBuilder
    private func projectsGrid(
        projects: [ProjectType],
        selected: Set<ProjectType>,
        toggle: @escaping (ProjectType) -> Void
    ) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
            ForEach(projects) { project in
                ProjectChipView(
                    project: project,
                    isSelected: selected.contains(project),
                    action: { toggle(project) }
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func summaryRow(key: String, value: Int, bold: Bool = false) -> some View {
        HStack {
            Text(LocalizedStringKey(key))
                .foregroundStyle(.secondary)
                .font(bold ? .subheadline.weight(.semibold) : .subheadline)
            Spacer()
            Text("\(value)")
                .font(bold ? .subheadline.weight(.bold) : .subheadline)
        }
    }
}

// MARK: - ViewModel extension for view-only helper
extension AddRoundViewModel {
    var lastEditedSideIsUs: Bool {
        // Expose a simple flag for disabling the them field in auto-complete mode
        // This is set internally; we derive from whether us was last edited or default
        !usBaseText.isEmpty
    }
}
