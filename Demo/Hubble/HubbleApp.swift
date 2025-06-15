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
            .colorScheme(.dark)
        }
        #if os(macOS)
        .defaultSize(width: 800, height: 800)
        #endif
    }
}
