
import SwiftUI

// MARK: - Main Game View

struct MainGameView: View {
    @Environment(GameState.self) var gs
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let saver  = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            Color(red:0.04,green:0.04,blue:0.10).ignoresSafeArea()

            VStack(spacing: 0) {
                hudBar
                canvasArea
                infoStrip
                statBarsSection
                actionBar
            }

            // Overlays
            achievementBanner
        }
        .onReceive(ticker) { _ in gs.tick() }
        .onReceive(saver)  { _ in gs.save() }
        .sheet(isPresented: Binding(
            get: { gs.showFoodMenu },
            set: { gs.showFoodMenu = $0 }
        )) { FoodMenuView() }
        .fullScreenCover(isPresented: Binding(
            get: { gs.showMiniGame },
            set: { gs.showMiniGame = $0 }
        )) { MiniGameView() }
        .sheet(isPresented: Binding(
            get: { gs.showAchievements },
            set: { gs.showAchievements = $0 }
        )) { AchievementsView() }
    }

    // MARK: HUD
    private var hudBar: some View {
        HStack {
            HStack(spacing: 8) {
                Text(gs.petName)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                Text((STAGES[gs.stage] ?? gs.stage.label).uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(LinearGradient(
                        colors: [Color(red:0.48,green:0.42,blue:0.96), Color(red:0.91,green:0.47,blue:0.98)],
                        startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(20)
                    .foregroundColor(.white)
                    .tracking(1)
            }
            Spacer()
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("🪙").font(.system(size: 14))
                    Text("\(Int(gs.coins))")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color(red:0.98,green:0.75,blue:0.14))
                }
                Text(gs.isNight ? "🌙" : "☀️").font(.system(size: 16))
                Button { gs.showAchievements = true } label: {
                    Text("🏆").font(.system(size: 18))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(red:0.10,green:0.10,blue:0.23))
        .overlay(Divider().background(Color.white.opacity(0.07)), alignment: .bottom)
    }

    // MARK: Canvas area
    private var canvasArea: some View {
        ZStack {
            BackgroundView()
            PetCanvasView()

            // Sick veil
            if gs.isSick {
                RadialGradient(
                    colors: [Color.green.opacity(0.07), .clear],
                    center: .center, startRadius: 0, endRadius: 200)
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // Speech bubble
            if let speech = gs.speechMessage {
                VStack {
                    SpeechBubble(text: speech)
                    Spacer()
                }
                .padding(.top, 12)
                .transition(.scale.combined(with: .opacity))
            }

            // Event banner
            if let evt = gs.eventMessage {
                VStack {
                    Spacer()
                    Text(evt)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(gs.eventIsPositive
                                ? Color.green.opacity(0.4)
                                : Color.red.opacity(0.4), lineWidth: 1))
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(height: 270)
        .clipped()
        .animation(.easeInOut(duration: 0.3), value: gs.speechMessage)
        .animation(.easeInOut(duration: 0.4), value: gs.eventMessage)
    }

    // MARK: Info strip
    private var infoStrip: some View {
        HStack {
            Text(ageString)
            Spacer()
            Text("\(gs.mood.emoji) \(gs.mood.label)")
            Spacer()
            Text(gs.evolutionPath == .default && gs.stage == .egg ? "Path: ???" : gs.evolutionPath.label)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(.gray)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(Color(red:0.10,green:0.10,blue:0.23))
        .overlay(Divider().background(Color.white.opacity(0.07)), alignment: .bottom)
    }

    private var ageString: String {
        let m = gs.ageInMinutes
        if m < 60   { return "Age: \(Int(m))m" }
        if m < 1440 { return "Age: \(Int(m/60))h" }
        return "Age: \(Int(m/1440))d"
    }

    // MARK: Stat bars
    private var statBarsSection: some View {
        VStack(spacing: 7) {
            StatBar(icon:"🍖", label:"HUNGER",  value: gs.hunger,
                    gradient: Gradient(colors:[Color(red:0.98,green:0.45,blue:0.09), Color(red:0.98,green:0.75,blue:0.14)]))
            StatBar(icon:"😊", label:"HAPPY",   value: gs.happiness,
                    gradient: Gradient(colors:[Color(red:0.91,green:0.47,blue:0.98), Color(red:0.94,green:0.67,blue:0.99)]))
            StatBar(icon:"❤️", label:"HEALTH",  value: gs.health,
                    gradient: Gradient(colors:[Color(red:0.13,green:0.77,blue:0.37), Color(red:0.53,green:0.94,blue:0.67)]))
            StatBar(icon:"⚡", label:"ENERGY",  value: gs.energy,
                    gradient: Gradient(colors:[Color(red:0.02,green:0.71,blue:0.84), Color(red:0.40,green:0.91,blue:0.98)]))
            StatBar(icon:"✨", label:"CLEAN",   value: gs.cleanliness,
                    gradient: Gradient(colors:[Color(red:0.48,green:0.42,blue:0.96), Color(red:0.65,green:0.55,blue:0.98)]))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(red:0.10,green:0.10,blue:0.23))
        .overlay(Divider().background(Color.white.opacity(0.07)), alignment: .bottom)
    }

    // MARK: Action bar
    private var actionBar: some View {
        let sleeping = gs.isSleeping
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6),
                         spacing: 6) {
            ActionButton(icon:"🍖", label:"Feed",  action:{ gs.showFoodMenu = true },
                         isDisabled: sleeping)
            ActionButton(icon:"🎮", label:"Play",  action:{ gs.showMiniGame = true },
                         isDisabled: sleeping || gs.energy < 10)
            ActionButton(icon: sleeping ? "☀️" : "💤",
                         label: sleeping ? "Wake" : "Sleep",
                         action:{ gs.toggleSleep() },
                         isActive: sleeping)
            ActionButton(icon:"🛁", label:"Clean",  action:{ gs.clean() },
                         isDisabled: sleeping)
            ActionButton(icon:"💊", label:"Meds",   action:{ gs.giveMedicine() },
                         isDisabled: !gs.isSick)
            ActionButton(icon:"🏃", label:"Train",  action:{ gs.exercise() },
                         isDisabled: sleeping || gs.energy < 20)
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .background(Color(red:0.10,green:0.10,blue:0.23))
    }

    // MARK: Achievement banner
    @ViewBuilder
    private var achievementBanner: some View {
        if let ach = gs.newAchievement {
            VStack {
                HStack(spacing: 10) {
                    Text(ach.emoji).font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACHIEVEMENT UNLOCKED!")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red:0.98,green:0.75,blue:0.14))
                            .tracking(1.5)
                        Text(ach.label)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                }
                .padding(14)
                .background(LinearGradient(
                    colors: [Color(red:0.10,green:0.10,blue:0.23), Color(red:0.16,green:0.10,blue:0.29)],
                    startPoint: .leading, endPoint: .trailing))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red:0.98,green:0.75,blue:0.14).opacity(0.5), lineWidth: 1))
                .cornerRadius(14)
                .shadow(color: Color(red:0.98,green:0.75,blue:0.14).opacity(0.2), radius: 12)
                .padding(.horizontal, 16).padding(.top, 8)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: gs.newAchievement?.id)
            .zIndex(10)
        }
    }
}

// MARK: Stage label helper
private let STAGES: [LifeStage: String] = [
    .egg: "Egg", .baby: "Baby", .child: "Child",
    .teen: "Teen", .adult: "Adult", .elder: "Elder"
]

// MARK: - Speech Bubble
struct SpeechBubble: View {
    let text: String
    var body: some View {
        ZStack(alignment: .bottom) {
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.3), radius: 4)
            // Tail
            Triangle()
                .fill(.white)
                .frame(width: 14, height: 8)
                .offset(y: 7)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
