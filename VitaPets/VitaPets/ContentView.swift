import SwiftUI

struct ContentView: View {
    @Environment(GameState.self) private var gs

    var body: some View {
        Group {
            if gs.petName.isEmpty {
                NameScreenView()
            } else {
                MainGameView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: gs.petName.isEmpty)
    }
}
