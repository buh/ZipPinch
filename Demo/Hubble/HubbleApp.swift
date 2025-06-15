import SwiftUI

@main
struct HubbleApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                ContentView()
            }
            .preferredColorScheme(.dark)
        }
    }
}
