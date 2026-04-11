import SwiftUI

// MARK: - Treat Catcher Mini-Game
struct MiniGameView: View {
    @Environment(GameState.self) private var gs
    @Environment(\.dismiss) private var dismiss

    @State private var basketX: CGFloat = 0.5        // 0…1 normalized
    @State private var treats: [FallingTreat] = []
    @State private var score: Int = 0
    @State private var combo: Int = 0
    @State private var timeLeft: Double = 30
    @State private var gamePhase: GamePhase = .countdown
    @State private var countdown: Int = 3
    @State private var particles: [ScoreParticle] = []
    @State private var shakeOffset: CGFloat = 0
    @State private var dragStart: CGFloat? = nil

    private let basketW: CGFloat = 90
    private let basketH: CGFloat = 40
    private let treatSize: CGFloat = 36
    private let spawnInterval: Double = 0.55
    private let fallDuration: Double = 2.2

    enum GamePhase { case countdown, playing, results }

    struct FallingTreat: Identifiable {
        let id = UUID()
        let emoji: String
        let xNorm: CGFloat       // 0…1
        let spawnTime: Date
        let duration: Double
        var caught = false
        var missed = false
        // is this a bomb? (penalty)
        let isBomb: Bool
    }

    struct ScoreParticle: Identifiable {
        let id = UUID()
        var position: CGPoint
        let text: String
        let color: Color
        var opacity: Double = 1
        var offset: CGFloat = 0
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.02, blue: 0.15),
                             Color(red: 0.1, green: 0.05, blue: 0.25)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                switch gamePhase {
                case .countdown:
                    countdownOverlay(size: size)
                case .playing:
                    gameCanvas(size: size)
                case .results:
                    resultsOverlay(size: size)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if gamePhase == .playing {
                            basketX = max(0, min(1, v.location.x / size.width))
                        }
                    }
            )
            .onAppear {
                basketX = 0.5
                startCountdown()
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Canvas Game
    @ViewBuilder
    private func gameCanvas(size: CGSize) -> some View {
        TimelineView(.animation) { ctx in
            Canvas { context, _ in
                drawGame(context: context, size: size, now: ctx.date)
            }
        }
        .overlay(alignment: .top) {
            topHUD()
        }
        .overlay {
            // Score particles layer
            ForEach(particles) { p in
                Text(p.text)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(p.color)
                    .opacity(p.opacity)
                    .position(x: p.position.x, y: p.position.y - p.offset)
            }
        }
        .onReceive(
            Timer.publish(every: spawnInterval, on: .main, in: .common).autoconnect()
        ) { _ in
            guard gamePhase == .playing else { return }
            spawnTreat(in: size)
        }
        .onReceive(
            Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
        ) { _ in
            guard gamePhase == .playing else { return }
            timeLeft = max(0, timeLeft - 0.016)
            checkCollisions(size: size)
            updateParticles()
            if timeLeft <= 0 { endGame() }
        }
    }

    private func drawGame(context: GraphicsContext, size: CGSize, now: Date) {
        // Stars
        var rng = SystemRandomNumberGenerator()
        for i in 0..<40 {
            let x = CGFloat(i * 73 % Int(size.width))
            let y = CGFloat(i * 41 % Int(size.height * 0.7))
            let twinkle = 0.3 + 0.5 * abs(sin(now.timeIntervalSinceReferenceDate * 2 + Double(i)))
            context.fill(
                Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                with: .color(.white.opacity(twinkle))
            )
        }

        // Ground stripe
        context.fill(
            Path(roundedRect: CGRect(x: 0, y: size.height - 12, width: size.width, height: 12), cornerRadius: 0),
            with: .color(.purple.opacity(0.4))
        )

        // Draw treats
        for treat in treats where !treat.caught && !treat.missed {
            let elapsed = now.timeIntervalSince(treat.spawnTime)
            let progress = elapsed / treat.duration
            guard progress <= 1 else { continue }
            let x = treat.xNorm * size.width
            let y = progress * (size.height - basketH - 20) + 30
            context.draw(
                Text(treat.emoji).font(.system(size: treatSize)),
                at: CGPoint(x: x, y: y)
            )
            if treat.isBomb {
                // Red warning circle
                context.stroke(
                    Path(ellipseIn: CGRect(x: x - 20, y: y - 20, width: 40, height: 40)),
                    with: .color(.red.opacity(0.4)),
                    lineWidth: 2
                )
            }
        }

        // Basket
        let bx = basketX * size.width - basketW / 2
        let by = size.height - basketH - 16
        let basketRect = CGRect(x: bx, y: by, width: basketW, height: basketH)

        // Basket glow
        let glowGrad = Gradient(colors: [.purple.opacity(0.4), .clear])
        context.fill(
            Path(ellipseIn: CGRect(x: bx - 10, y: by - 8, width: basketW + 20, height: basketH + 20)),
            with: .linearGradient(glowGrad, startPoint: CGPoint(x: bx, y: by), endPoint: CGPoint(x: bx, y: by + basketH + 20))
        )

        // Basket body
        var basketPath = Path()
        basketPath.move(to: CGPoint(x: bx, y: by))
        basketPath.addLine(to: CGPoint(x: bx + 10, y: by + basketH))
        basketPath.addLine(to: CGPoint(x: bx + basketW - 10, y: by + basketH))
        basketPath.addLine(to: CGPoint(x: bx + basketW, y: by))
        basketPath.closeSubpath()
        context.fill(basketPath, with: .color(.purple.opacity(0.7)))
        context.stroke(basketPath, with: .color(.white.opacity(0.6)), lineWidth: 2)

        // Combo indicator in basket
        if combo > 1 {
            context.draw(
                Text("×\(combo)").font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.yellow),
                at: CGPoint(x: bx + basketW / 2, y: by + basketH / 2)
            )
        }
    }

    @ViewBuilder
    private func topHUD() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(score)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
            }
            Spacer()
            // Timer arc
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 5)
                    .frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: timeLeft / 30)
                    .stroke(timeLeft < 8 ? Color.red : Color.purple, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(ceil(timeLeft)))")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("COMBO")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text(combo > 1 ? "×\(combo)" : "—")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(combo > 3 ? .orange : .white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - Countdown
    @ViewBuilder
    private func countdownOverlay(size: CGSize) -> some View {
        VStack(spacing: 20) {
            Text("TREAT CATCHER")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Drag to move the basket\nCatch treats, avoid bombs 💣")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 120, height: 120)
                Text("\(countdown)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .animation(.spring(response: 0.4), value: countdown)
        }
    }

    // MARK: - Results
    @ViewBuilder
    private func resultsOverlay(size: CGSize) -> some View {
        VStack(spacing: 24) {
            Text(score >= 15 ? "🎉" : score >= 8 ? "✨" : "😅")
                .font(.system(size: 72))

            Text(score >= 15 ? "AMAZING!" : score >= 8 ? "NICE JOB!" : "KEEP TRYING!")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ResultRow(label: "Treats caught", value: "\(score)")
                ResultRow(label: "Best combo", value: "×\(combo)")
                ResultRow(label: "Coins earned", value: "🪙 \(coinsEarned())")
            }
            .padding(20)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                gs.rewardMiniGame(score: score, combo: combo)
                dismiss()
            } label: {
                Label("CLAIM REWARD", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
        }
        .padding(24)
    }

    // MARK: - Logic
    private func startCountdown() {
        countdown = 3
        gamePhase = .countdown
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            countdown -= 1
            if countdown <= 0 {
                t.invalidate()
                withAnimation { gamePhase = .playing }
            }
        }
    }

    private func spawnTreat(in size: CGSize) {
        let treatEmojis = ["🍖", "🐟", "🥕", "⭐️", "🍪", "🎁", "🍗", "🍎"]
        let isBomb = Int.random(in: 0..<6) == 0
        let emoji = isBomb ? "💣" : treatEmojis.randomElement()!
        let xNorm = CGFloat.random(in: 0.08...0.92)
        let dur = Double.random(in: fallDuration * 0.85 ... fallDuration * 1.15)
        let t = FallingTreat(emoji: emoji, xNorm: xNorm, spawnTime: Date(), duration: dur, isBomb: isBomb)
        treats.append(t)

        // Prune old treats
        if treats.count > 30 {
            treats = treats.filter { !$0.caught && !$0.missed }
        }
    }

    private func checkCollisions(size: CGSize) {
        let now = Date()
        let bx = basketX * size.width
        let by = size.height - basketH - 16
        let catchZoneY = by + 8

        for i in treats.indices {
            guard !treats[i].caught && !treats[i].missed else { continue }
            let elapsed = now.timeIntervalSince(treats[i].spawnTime)
            let progress = elapsed / treats[i].duration
            let treatY = progress * (size.height - basketH - 20) + 30
            let treatX = treats[i].xNorm * size.width

            // Miss: fell past basket
            if progress >= 1 {
                treats[i].missed = true
                if !treats[i].isBomb {
                    combo = 0
                }
                continue
            }

            // Catch: within basket range
            if treatY >= catchZoneY && treatY <= catchZoneY + basketH &&
               abs(treatX - bx) < (basketW / 2 + treatSize / 2) {
                treats[i].caught = true
                if treats[i].isBomb {
                    // Penalty
                    score = max(0, score - 3)
                    combo = 0
                    addParticle(at: CGPoint(x: treatX, y: treatY), text: "-3", color: .red)
                    triggerShake()
                } else {
                    combo += 1
                    let earned = combo > 3 ? 2 : 1
                    score += earned
                    let txt = combo > 3 ? "+\(earned) 🔥" : "+\(earned)"
                    addParticle(at: CGPoint(x: treatX, y: treatY), text: txt, color: combo > 3 ? .orange : .yellow)
                }
            }
        }
    }

    private func addParticle(at pos: CGPoint, text: String, color: Color) {
        var p = ScoreParticle(position: pos, text: text, color: color)
        particles.append(p)
    }

    private func updateParticles() {
        for i in particles.indices {
            particles[i].offset += 1.2
            particles[i].opacity = max(0, particles[i].opacity - 0.025)
        }
        particles = particles.filter { $0.opacity > 0 }
    }

    private func triggerShake() {
        withAnimation(.default) { shakeOffset = 8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default) { shakeOffset = -8 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.default) { shakeOffset = 0 }
            }
        }
    }

    private func endGame() {
        withAnimation { gamePhase = .results }
    }

    private func coinsEarned() -> Int {
        max(1, score / 3 + (combo > 3 ? 3 : 0))
    }
}

private struct ResultRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
