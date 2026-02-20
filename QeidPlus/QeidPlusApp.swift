import SwiftUI

@main
struct QeidPlusApp: App {
    @StateObject private var gameVM = GameViewModel()

    var body: some Scene {
        WindowGroup {
            GameScreen(gameVM: gameVM)
        }
    }
}
