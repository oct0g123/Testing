import SwiftUI

@main
struct VitaPetsApp: App {
    @State private var gameState = GameState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gameState)
                .onAppear {
                    let loaded = gameState.load()
                    // If nothing was saved, petName stays "" → NameScreenView shows
                    _ = loaded
                }
                .preferredColorScheme(.dark)
        }
#if os(visionOS)
        .defaultSize(width: 400, height: 750)
#endif
    }
}
