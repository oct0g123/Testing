
import SwiftUI

// MARK: - Name Screen

struct NameScreenView: View {
    @Environment(GameState.self) var gs
    @State private var petName = ""
    @State private var animTime: Double = 0
    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Space background
            RadialGradient(
                colors: [Color(red:0.10,green:0.06,blue:0.25), Color(red:0.04,green:0.04,blue:0.10)],
                center: .center, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("VITAPETS")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red:0.48,green:0.42,blue:0.96), Color(red:0.91,green:0.47,blue:0.98)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .tracking(8)

                Text("YOUR COSMIC COMPANION")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(3)

                // Animated egg canvas
                TimelineView(.animation) { tl in
                    Canvas { ctx, size in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        drawEggPreview(ctx: ctx, size: size, time: t)
                    }
                }
                .frame(width: 180, height: 180)

                Text("Name your new companion")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.gray)

                TextField("Enter a name…", text: $petName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20).padding(.vertical, 13)
                    .background(Color(red:0.10,green:0.10,blue:0.23))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red:0.48,green:0.42,blue:0.96), lineWidth: 2))
                    .cornerRadius(12)
                    .frame(maxWidth: 280)
                    .autocorrectionDisabled()
                    .onSubmit { hatch() }

                Button(action: hatch) {
                    Text("HATCH EGG ✨")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32).padding(.vertical, 14)
                        .background(LinearGradient(
                            colors: [Color(red:0.48,green:0.42,blue:0.96), Color(red:0.91,green:0.47,blue:0.98)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .cornerRadius(12)
                        .shadow(color: Color(red:0.48,green:0.42,blue:0.96).opacity(0.4), radius: 12)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }

    private func hatch() {
        let name = petName.trimmingCharacters(in: .whitespaces)
        gs.reset(name: name.isEmpty ? "Vita" : name)
    }

    private func drawEggPreview(ctx: GraphicsContext, size: CGSize, time: Double) {
        let cx = size.width / 2, cy = size.height / 2
        let bounceY = sin(time / 0.70) * 5.0
        let oy = cy + bounceY

        // Glow
        let glow = Ellipse().path(in: CGRect(x: cx-70, y: oy-80, width: 140, height: 160))
        ctx.fill(glow, with: .radialGradient(
            Gradient(colors: [Color.purple.opacity(0.2), .clear]),
            center: CGPoint(x: cx, y: oy), startRadius: 0, endRadius: 75))

        // Egg body
        let eggRect = CGRect(x: cx-42, y: oy-52, width: 84, height: 104)
        let egg = Ellipse().path(in: eggRect)
        ctx.fill(egg, with: .linearGradient(
            Gradient(colors: [Color(red:0.92,green:0.85,blue:1.0), Color(red:0.78,green:0.66,blue:0.94), Color(red:0.56,green:0.38,blue:0.78)]),
            startPoint: CGPoint(x: cx-20, y: oy-40), endPoint: CGPoint(x: cx+20, y: oy+40)))
        ctx.stroke(egg, with: .color(.white.opacity(0.25)), lineWidth: 1.5)

        // Shine
        let shineRect = CGRect(x: cx-28, y: oy-44, width: 18, height: 12)
        ctx.fill(Ellipse().path(in: shineRect), with: .color(.white.opacity(0.5)))

        // Sparkles
        let sparkles = ["✨","⭐","💫"]
        for (i, sp) in sparkles.enumerated() {
            let alpha = sin(time * 1.5 + Double(i) * 2.0) * 0.5 + 0.5
            let x = 20.0 + Double(i) * 52.0
            let y = 30.0 + sin(time + Double(i)) * 8.0
            ctx.opacity = alpha
            ctx.draw(Text(sp).font(.system(size: 14)), at: CGPoint(x: x, y: y))
            ctx.opacity = 1
        }
    }
}
