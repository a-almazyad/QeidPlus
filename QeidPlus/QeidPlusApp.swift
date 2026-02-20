import SwiftUI

@main
struct QeidPlusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var gameVM = GameViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            GameScreen(gameVM: gameVM)
                .task {
                    await MobileBackendManager.shared.performLaunchSync()
                    let notificationManager = NotificationManager.shared
                    await notificationManager.refreshAuthorizationStatus()
                    if notificationManager.isAuthorized {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                Task { await MobileBackendManager.shared.endSession() }
            }
            if phase == .active {
                Task {
                    let notificationManager = NotificationManager.shared
                    await notificationManager.refreshAuthorizationStatus()
                    if notificationManager.isAuthorized {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
    }
}
