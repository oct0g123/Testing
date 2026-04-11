
import SwiftUI

// MARK: - Background (star field + nebula + moon/sun)

struct BackgroundView: View {
    @Environment(GameState.self) var gs
    private struct Star: Identifiable {
        let id = UUID()
        let x, y, r, phase, speed: Double
    }
    private let stars: [Star] = (0..<80).map { _ in
        Star(x: Double.random(in:0...1), y: Double.random(in:0...1),
             r: Double.random(in:0.3...1.7), phase: Double.random(in:0...6.28),
             speed: Double.random(in:0.3...0.9))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { tl in
            Canvas { ctx, size in
                let t    = tl.date.timeIntervalSinceReferenceDate
                let night = gs.isNight
                let W = size.width, H = size.height

                // Sky gradient
                let skyColors: [Color] = night
                    ? [Color(red:0.03,green:0.03,blue:0.10), Color(red:0.07,green:0.07,blue:0.18)]
                    : [Color(red:0.07,green:0.08,blue:0.25), Color(red:0.12,green:0.10,blue:0.30)]
                ctx.fill(Path(CGRect(x:0,y:0,width:W,height:H)),
                         with:.linearGradient(Gradient(colors:skyColors),
                                              startPoint:.zero, endPoint:CGPoint(x:0,y:H)))

                // Stars
                for s in stars {
                    let twink = 0.4 + 0.6 * sin(t * s.speed + s.phase)
                    let a = night ? 0.35 + 0.6*twink : 0.12 + 0.18*twink
                    let sr = s.r
                    ctx.fill(Circle().path(in: CGRect(x: s.x*W-sr, y: s.y*H-sr, width: sr*2, height: sr*2)),
                             with: .color(.white.opacity(a)))
                }

                // Nebula blobs
                ctx.fill(Path(CGRect(x:0,y:0,width:W,height:H)),
                         with:.radialGradient(Gradient(colors:[Color(red:0.48,green:0.42,blue:0.96).opacity(0.08),.clear]),
                                              center:CGPoint(x:W*0.16,y:H*0.20), startRadius:0, endRadius:W*0.22))
                ctx.fill(Path(CGRect(x:0,y:0,width:W,height:H)),
                         with:.radialGradient(Gradient(colors:[Color(red:0.91,green:0.47,blue:0.98).opacity(0.06),.clear]),
                                              center:CGPoint(x:W*0.85,y:H*0.75), startRadius:0, endRadius:W*0.24))

                // Moon or sun
                if night {
                    let mx: CGFloat = W * 0.90, my: CGFloat = H * 0.13
                    ctx.fill(Circle().path(in: CGRect(x:mx-16,y:my-16,width:32,height:32)),
                             with:.color(.yellow.opacity(0.9)))
                    ctx.fill(Circle().path(in: CGRect(x:mx+4,y:my-14,width:26,height:26)),
                             with:.color(Color(red:0.04,green:0.04,blue:0.10)))
                } else {
                    ctx.fill(Path(CGRect(x:0,y:0,width:W,height:H)),
                             with:.radialGradient(
                                Gradient(colors:[Color(red:1.0,green:0.86,blue:0.35).opacity(0.9),
                                                 Color(red:1.0,green:0.71,blue:0.16).opacity(0.5),.clear]),
                                center:CGPoint(x:W*0.90,y:H*0.13), startRadius:0, endRadius:24))
                }

                // Ground glow
                let gx = W/2, gy: CGFloat = H
                ctx.fill(Path(CGRect(x:0,y:0,width:W,height:H)),
                         with:.radialGradient(
                            Gradient(colors:[Color(red:0.48,green:0.42,blue:0.96).opacity(0.14),.clear]),
                            center:CGPoint(x:gx,y:gy), startRadius:0, endRadius:W*0.35))
            }
        }
    }
}

// MARK: - Stat Bar

struct StatBar: View {
    let icon: String
    let label: String
    let value: Double
    let gradient: Gradient

    private var isDanger: Bool { value < 25 }

    var body: some View {
        HStack(spacing: 8) {
            Text(icon).font(.system(size: 15))
                .frame(width: 18)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(.gray)
                .frame(width: 55, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(gradient: gradient,
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * value / 100))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
                }
            }
            .frame(height: 9)
            Text("\(Int(value))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 24, alignment: .trailing)
        }
        .opacity(isDanger ? 1 : 1)
        .overlay {
            if isDanger {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var isActive: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(icon).font(.system(size: 22))
                Text(label)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(0.3)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive
                ? Color(red:0.48,green:0.42,blue:0.96).opacity(0.25)
                : Color(red:0.07,green:0.07,blue:0.18))
            .overlay(RoundedRectangle(cornerRadius: 11)
                .stroke(isActive
                    ? Color(red:0.48,green:0.42,blue:0.96).opacity(0.5)
                    : Color.white.opacity(0.07), lineWidth: 1))
            .cornerRadius(11)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.3 : 1)
    }
}
