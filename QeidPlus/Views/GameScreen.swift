import SwiftUI

struct GameScreen: View {
    @ObservedObject var gameVM: GameViewModel

    @State private var showAddRound = false
    @State private var showReset = false
    @State private var showShare = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Score cards
                HStack(spacing: 12) {
                    ScoreCardView(
                        teamKey: "team_us",
                        score: gameVM.match.usTotal,
                        hasWon: gameVM.match.winner == .us
                    )
                    ScoreCardView(
                        teamKey: "team_them",
                        score: gameVM.match.themTotal,
                        hasWon: gameVM.match.winner == .them
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // Rounds list
                if gameVM.match.rounds.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(gameVM.match.rounds.reversed()) { round in
                            RoundRowView(round: round)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        HapticFeedback.notification(.warning)
                                        gameVM.deleteRound(id: round.id)
                                    } label: {
                                        Label(NSLocalizedString("delete", comment: ""), systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                // Add round button
                Button {
                    showAddRound = true
                } label: {
                    Label(NSLocalizedString("add_round", comment: ""), systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .padding(.top, 8)
                }
            }
            .navigationTitle(NSLocalizedString("app_name", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    // Settings
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Undo
                    Button {
                        HapticFeedback.impact(.light)
                        gameVM.undoLastRound()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!gameVM.canUndo)

                    // Redo
                    Button {
                        HapticFeedback.impact(.light)
                        gameVM.redoLastRound()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!gameVM.canRedo)

                    // Share
                    Button {
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(gameVM.match.rounds.isEmpty)

                    // Reset
                    Button {
                        showReset = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .disabled(gameVM.match.rounds.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showAddRound) {
            AddRoundSheet(gameVM: gameVM)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { gameVM.showWinner },
            set: { if !$0 { gameVM.dismissWinner() } }
        )) {
            if let winner = gameVM.match.winner {
                WinnerModalView(
                    winner: winner,
                    usTotal: gameVM.match.usTotal,
                    themTotal: gameVM.match.themTotal,
                    onReset: {
                        gameVM.resetGame()
                    },
                    onDismiss: {
                        gameVM.dismissWinner()
                    }
                )
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [gameVM.shareText])
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            NSLocalizedString("reset_confirm_title", comment: ""),
            isPresented: $showReset,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("reset_game", comment: ""), role: .destructive) {
                HapticFeedback.notification(.warning)
                gameVM.resetGame()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("reset_confirm_message"))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(LocalizedStringKey("empty_rounds_title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey("empty_rounds_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    GameScreen(gameVM: GameViewModel())
}
