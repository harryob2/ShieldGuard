import SwiftUI

@main
struct ShieldGuardApp: App {
    @StateObject private var viewModel = ShieldGuardViewModel()

    var body: some Scene {
        WindowGroup("ShieldGuard") {
            ContentView(viewModel: viewModel)
        }
    }
}
