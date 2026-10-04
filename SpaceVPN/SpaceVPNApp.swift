import SwiftUI

@main
struct SpaceVPNApp: App {
    @StateObject private var vpn = VPNManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vpn)
                .preferredColorScheme(.dark)
        }
    }
}
