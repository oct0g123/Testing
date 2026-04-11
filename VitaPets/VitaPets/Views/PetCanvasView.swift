
import SwiftUI

// MARK: - Pet Canvas View (TimelineView + Canvas)

struct PetCanvasView: View {
    @Environment(GameState.self) var gs

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t  = tl.date.timeIntervalSinceReferenceDate
                let cx = size.width  / 2
                let cy = size.height / 2
                let bounce = sin(t / (gs.isSleeping ? 1.3 : 0.52))
                           * (gs.isSleeping ? 2 : 5)
                let sc = gs.stage.scale

                drawShadow(ctx: ctx, cx: cx, cy: cy, sc: sc, bounce: bounce)

                if gs.stage == .egg {
                    drawEgg(ctx: ctx, cx: cx, cy: cy + bounce, sc: sc,
                            t: t, ageMin: gs.ageInMinutes)
                } else {
                    drawCreature(ctx: ctx, cx: cx, cy: cy + bounce,
                                 sc: sc, t: t)
                }
            }
        }
    }

    // MARK: Shadow
    private func drawShadow(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                            sc: CGFloat, bounce: CGFloat) {
        let shadowY = cy + 65 * sc
        let w = 55 * sc, h = 14 * sc
        let shadowRect = CGRect(x: cx-w, y: shadowY-h, width: w*2, height: h*2)
        let alpha = max(0, 0.22 - abs(bounce) * 0.004)
        ctx.fill(Ellipse().path(in: shadowRect), with: .color(.black.opacity(alpha)))
    }

    // MARK: Egg
    private func drawEgg(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                         sc: CGFloat, t: Double, ageMin: Double) {
        let r = 38 * sc
        let prog = min(1.0, ageMin / 5.0)

        // Glow
        let glowRect = CGRect(x: cx - r*1.7, y: cy - r*2.1, width: r*3.4, height: r*4.2)
        ctx.fill(Ellipse().path(in: glowRect), with: .radialGradient(
            Gradient(colors: [Color.purple.opacity(0.15), .clear]),
            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r * 1.7))

        // Egg body
        let eggRect = CGRect(x: cx - r*0.84, y: cy - r, width: r*1.68, height: r*2)
        let egg = Ellipse().path(in: eggRect)
        ctx.fill(egg, with: .linearGradient(
            Gradient(colors: [Color(red:0.92,green:0.85,blue:1.0), Color(red:0.78,green:0.66,blue:0.94), Color(red:0.56,green:0.38,blue:0.78)]),
            startPoint: CGPoint(x: cx-r*0.3, y: cy-r*0.4),
            endPoint:   CGPoint(x: cx+r*0.3, y: cy+r*0.4)))
        ctx.stroke(egg, with: .color(.white.opacity(0.25)), lineWidth: 1.5)

        // Shine
        let shineRect = CGRect(x: cx - r*0.33, y: cy - r*0.41, width: r*0.26, height: r*0.18)
        ctx.fill(Ellipse().path(in: shineRect), with: .color(.white.opacity(0.5)))

        // Cracks
        if prog > 0.3 {
            var crack = Path()
            crack.move(to: CGPoint(x: cx, y: cy - r*0.28))
            crack.addLine(to: CGPoint(x: cx + r*0.18*prog, y: cy))
            crack.addLine(to: CGPoint(x: cx, y: cy + r*0.18*prog))
            ctx.stroke(crack, with: .color(Color.purple.opacity(0.55)), lineWidth: 1.5)
        }
        if prog > 0.7 {
            var crack2 = Path()
            crack2.move(to: CGPoint(x: cx - r*0.1, y: cy - r*0.2))
            crack2.addLine(to: CGPoint(x: cx - r*0.28*prog, y: cy + r*0.1))
            ctx.stroke(crack2, with: .color(Color.purple.opacity(0.55)), lineWidth: 1.5)
            ctx.draw(Text("✨").font(.system(size: 12*prog)), at: CGPoint(x: cx, y: cy + r*0.45*prog))
        }

        // ? wobble
        let wobble = sin(t / 0.8) * 3
        ctx.draw(
            Text("?").font(.system(size: 17*sc, weight: .black, design: .monospaced))
                .foregroundColor(.init(red:0.75,green:0.61,blue:0.90)),
            at: CGPoint(x: cx + wobble, y: cy + r*0.28))
    }

    // MARK: Creature
    private func drawCreature(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                               sc: CGFloat, t: Double) {
        let pal = gs.evolutionPath
        let mood = gs.mood

        // Aura
        let auraR = 52 * sc
        let auraRect = CGRect(x: cx-auraR, y: cy-auraR, width: auraR*2, height: auraR*2)
        ctx.fill(Circle().path(in: auraRect), with: .radialGradient(
            Gradient(colors: [pal.auraColor, .clear]),
            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: auraR))

        // Sick aura
        if gs.isSick {
            let sr = 46 * sc
            let sRect = CGRect(x: cx-sr, y: cy-sr, width: sr*2, height: sr*2)
            ctx.fill(Circle().path(in: sRect), with: .radialGradient(
                Gradient(colors: [Color.green.opacity(0.18), .clear]),
                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: sr))
        }

        // Ears (behind body)
        drawEars(ctx: ctx, cx: cx, cy: cy, sc: sc, pal: pal)

        // Body blob
        let br = 35 * sc
        var pts: [CGPoint] = []
        for i in 0..<8 {
            let angle = Double(i) / 8.0 * .pi * 2 - .pi / 2
            let wobble = sin(t / 0.58 + Double(i) * 0.9) * 2 * Double(sc)
            let rx = Double(br) + (i % 2 == 0 ? 3*Double(sc) : 0) + wobble
            let ry = Double(br)*1.1 + (i % 2 == 0 ? 0 : 2*Double(sc)) + wobble
            pts.append(CGPoint(x: cx + CGFloat(cos(angle) * rx), y: cy + CGFloat(sin(angle) * ry)))
        }
        let body = blobPath(pts: pts)
        ctx.fill(body, with: .linearGradient(
            Gradient(colors: [pal.bodyColor.opacity(0.85), pal.bodyColor, pal.bodyColor.opacity(0.7)]),
            startPoint: CGPoint(x: cx - br*0.3, y: cy - br*0.4),
            endPoint:   CGPoint(x: cx + br*0.3, y: cy + br*0.4)))
        ctx.stroke(body, with: .color(pal.bodyColor.opacity(0.5)), lineWidth: 1.5)

        // Belly
        let bellyRect = CGRect(x: cx - 17*sc, y: cy - 5*sc, width: 34*sc, height: 26*sc)
        ctx.fill(Ellipse().path(in: bellyRect), with: .color(pal.bellyColorFixed.opacity(0.65)))

        // Markings
        drawMarkings(ctx: ctx, cx: cx, cy: cy, sc: sc, pal: pal, t: t)

        // Eyes
        drawEyes(ctx: ctx, cx: cx, cy: cy, sc: sc, mood: mood, t: t)

        // Mouth
        drawMouth(ctx: ctx, cx: cx, cy: cy, sc: sc, mood: mood)

        // Elder glasses
        if gs.stage == .elder {
            let lx = cx - 10*sc, rx2 = cx + 10*sc, ey2 = cy - 10*sc, gr = 7*sc
            ctx.stroke(Circle().path(in: CGRect(x: lx-gr, y: ey2-gr, width: gr*2, height: gr*2)),
                       with: .color(.gray), lineWidth: 1.5)
            ctx.stroke(Circle().path(in: CGRect(x: rx2-gr, y: ey2-gr, width: gr*2, height: gr*2)),
                       with: .color(.gray), lineWidth: 1.5)
            var bridge = Path()
            bridge.move(to: CGPoint(x: cx-3*sc, y: ey2))
            bridge.addLine(to: CGPoint(x: cx+3*sc, y: ey2))
            ctx.stroke(bridge, with: .color(.gray), lineWidth: 1.5)
        }

        // Perfect crown
        if gs.evolutionPath == .perfect && (gs.stage == .adult || gs.stage == .elder) {
            var crown = Path()
            let cb = cy - 42*sc
            crown.move(to: CGPoint(x: cx - 12*sc, y: cb))
            crown.addLine(to: CGPoint(x: cx - 12*sc, y: cy - 50*sc))
            crown.addLine(to: CGPoint(x: cx - 6*sc,  y: cy - 44*sc))
            crown.addLine(to: CGPoint(x: cx,          y: cy - 54*sc))
            crown.addLine(to: CGPoint(x: cx + 6*sc,  y: cy - 44*sc))
            crown.addLine(to: CGPoint(x: cx + 12*sc, y: cy - 50*sc))
            crown.addLine(to: CGPoint(x: cx + 12*sc, y: cb))
            crown.closeSubpath()
            ctx.fill(crown, with: .color(Color(red:0.98,green:0.75,blue:0.14)))
            ctx.stroke(crown, with: .color(Color(red:0.85,green:0.55,blue:0.05)), lineWidth: 1)
        }

        // Sleeping ZZZ
        if gs.isSleeping {
            for (i, ch) in ["z","Z","Z"].enumerated() {
                let alpha = max(0, sin(t + Double(i) * 0.9) * 0.5 + 0.5)
                let zx = cx + 20*sc + CGFloat(i)*7*sc
                let zy = cy - 30*sc - CGFloat(i)*9*sc - CGFloat(sin(t + Double(i)) * 4)
                ctx.opacity = alpha
                ctx.draw(
                    Text(ch).font(.system(size: CGFloat(9+i*4)*sc, weight: .black))
                        .foregroundColor(Color(red:0.63,green:0.78,blue:1.0)),
                    at: CGPoint(x: zx, y: zy))
                ctx.opacity = 1
            }
        }

        // Poop indicators
        for i in 0..<gs.poopCount {
            ctx.draw(Text("💩").font(.system(size: 14)),
                     at: CGPoint(x: cx + 55*sc + CGFloat(i)*18, y: cy + 30*sc))
        }
    }

    // MARK: Ears
    private func drawEars(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                          sc: CGFloat, pal: EvolutionPath) {
        let earColor = pal.bodyColor.opacity(0.85)
        switch pal.earStyle {
        case .sharp:
            var left = Path()
            left.move(to: CGPoint(x: cx-30*sc, y: cy-28*sc))
            left.addLine(to: CGPoint(x: cx-22*sc, y: cy-48*sc))
            left.addLine(to: CGPoint(x: cx-14*sc, y: cy-26*sc))
            left.closeSubpath()
            ctx.fill(left, with: .color(earColor))
            var right = Path()
            right.move(to: CGPoint(x: cx+30*sc, y: cy-28*sc))
            right.addLine(to: CGPoint(x: cx+22*sc, y: cy-48*sc))
            right.addLine(to: CGPoint(x: cx+14*sc, y: cy-26*sc))
            right.closeSubpath()
            ctx.fill(right, with: .color(earColor))
        case .floppy:
            let lr = CGRect(x: cx-41*sc, y: cy-35*sc, width: 16*sc, height: 38*sc)
            let rr = CGRect(x: cx+25*sc, y: cy-35*sc, width: 16*sc, height: 38*sc)
            ctx.fill(Ellipse().path(in: lr), with: .color(earColor))
            ctx.fill(Ellipse().path(in: rr), with: .color(earColor))
        case .round:
            let er = 12 * sc
            ctx.fill(Circle().path(in: CGRect(x:cx-28*sc-er, y:cy-31*sc-er, width:er*2,height:er*2)), with:.color(earColor))
            ctx.fill(Circle().path(in: CGRect(x:cx+28*sc-er, y:cy-31*sc-er, width:er*2,height:er*2)), with:.color(earColor))
            let ir = 7 * sc
            ctx.fill(Circle().path(in: CGRect(x:cx-28*sc-ir, y:cy-31*sc-ir, width:ir*2,height:ir*2)), with:.color(pal.bodyColor.opacity(0.5)))
            ctx.fill(Circle().path(in: CGRect(x:cx+28*sc-ir, y:cy-31*sc-ir, width:ir*2,height:ir*2)), with:.color(pal.bodyColor.opacity(0.5)))
        }
    }

    // MARK: Eyes
    private func drawEyes(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                          sc: CGFloat, mood: PetMood, t: Double) {
        let ey = cy - 12*sc
        let ex1 = cx - 13*sc, ex2 = cx + 13*sc
        let isBlinking = Int(t * 3) % 120 == 0   // simple blink cadence

        if mood == .sleeping || isBlinking {
            for ex in [ex1, ex2] {
                var line = Path()
                line.move(to: CGPoint(x: ex-5*sc, y: ey))
                line.addLine(to: CGPoint(x: ex+5*sc, y: ey))
                ctx.stroke(line, with: .color(Color(red:0.17,green:0.17,blue:0.23)), lineWidth: 2.5*sc)
            }
            return
        }

        if mood == .sick {
            // Spiral/dot eyes (approximated)
            for ex in [ex1, ex2] {
                for i in stride(from: 0.0, to: 9.4, by: 0.5) {
                    let r = CGFloat(i * 1.4) * sc
                    let angle = i + t * 2
                    let dotX = ex + cos(angle) * r
                    let dotY = ey + sin(angle) * r
                    let dot = Circle().path(in: CGRect(x:dotX-1, y:dotY-1, width:2, height:2))
                    ctx.fill(dot, with: .color(Color(red:0.33,green:0.80,blue:0.20)))
                }
            }
            return
        }

        for ex in [ex1, ex2] {
            let er = 7 * sc
            ctx.fill(Circle().path(in: CGRect(x:ex-er,y:ey-er,width:er*2,height:er*2)),
                     with: .color(.white))

            if mood == .happy || mood == .excited {
                // Happy squint arc
                var arc = Path()
                arc.move(to: CGPoint(x: ex-5*sc, y: ey+2*sc))
                arc.addQuadCurve(to: CGPoint(x: ex+5*sc, y: ey+2*sc),
                                 control: CGPoint(x: ex, y: ey-4*sc))
                ctx.stroke(arc, with: .color(Color(red:0.17,green:0.17,blue:0.23)), lineWidth: 2.5*sc)
                // Shine dot
                let shine = Circle().path(in: CGRect(x:ex+1*sc, y:ey-4*sc, width:3*sc, height:3*sc))
                ctx.fill(shine, with: .color(.white))
            } else {
                // Pupil
                let po: CGFloat = mood == .sad ? 1.8*sc : 0
                let pr = 4.5 * sc
                ctx.fill(Circle().path(in: CGRect(x:ex-pr,y:ey+po-pr,width:pr*2,height:pr*2)),
                         with: .color(Color(red:0.13,green:0.13,blue:0.13)))
                let shine = Circle().path(in: CGRect(x:ex+1*sc, y:ey+po-3*sc, width:3*sc, height:3*sc))
                ctx.fill(shine, with: .color(.white))

                if mood == .sad {
                    // Droopy eyebrow
                    var brow = Path()
                    brow.move(to: CGPoint(x: ex-5*sc, y: ey-8*sc))
                    brow.addLine(to: CGPoint(x: ex+5*sc, y: ey-5*sc))
                    ctx.stroke(brow, with: .color(.gray), lineWidth: 1.5*sc)
                }
            }
        }
    }

    // MARK: Mouth
    private func drawMouth(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                            sc: CGFloat, mood: PetMood) {
        if mood == .sleeping { return }
        let my = cy + 5 * sc

        if mood == .sick {
            var m = Path()
            m.move(to: CGPoint(x: cx-10*sc, y: my+2*sc))
            m.addQuadCurve(to: CGPoint(x: cx, y: my+2*sc),
                           control: CGPoint(x: cx-5*sc, y: my+8*sc))
            m.addQuadCurve(to: CGPoint(x: cx+10*sc, y: my+2*sc),
                           control: CGPoint(x: cx+5*sc, y: my-4*sc))
            ctx.stroke(m, with: .color(Color(red:0.33,green:0.80,blue:0.20)), lineWidth: 2*sc)
            return
        }

        switch mood {
        case .happy, .excited:
            var m = Path()
            m.move(to: CGPoint(x: cx-10*sc, y: my))
            m.addQuadCurve(to: CGPoint(x: cx+10*sc, y: my),
                           control: CGPoint(x: cx, y: my+10*sc))
            ctx.stroke(m, with: .color(Color(red:0.17,green:0.17,blue:0.23)), lineWidth: 2*sc)
            if mood == .excited {
                var mouth2 = Path()
                mouth2.move(to: CGPoint(x: cx-8*sc, y: my))
                mouth2.addQuadCurve(to: CGPoint(x: cx+8*sc, y: my),
                                    control: CGPoint(x: cx, y: my+13*sc))
                ctx.fill(mouth2, with: .color(Color(red:1.0,green:0.42,blue:0.42)))
            }
        case .sad:
            var m = Path()
            m.move(to: CGPoint(x: cx-10*sc, y: my+6*sc))
            m.addQuadCurve(to: CGPoint(x: cx+10*sc, y: my+6*sc),
                           control: CGPoint(x: cx, y: my-4*sc))
            ctx.stroke(m, with: .color(Color(red:0.17,green:0.17,blue:0.23)), lineWidth: 2*sc)
        default:
            var m = Path()
            m.move(to: CGPoint(x: cx-8*sc, y: my+2*sc))
            m.addQuadCurve(to: CGPoint(x: cx+8*sc, y: my+2*sc),
                           control: CGPoint(x: cx, y: my+7*sc))
            ctx.stroke(m, with: .color(Color(red:0.17,green:0.17,blue:0.23)), lineWidth: 2*sc)
        }
    }

    // MARK: Markings
    private func drawMarkings(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                               sc: CGFloat, pal: EvolutionPath, t: Double) {
        let markColor = pal.bodyColor.opacity(0.45)
        switch pal {
        case .perfect:
            for (ox, oy) in [(-12.0,-5.0),(12.0,-5.0),(0.0,9.0)] {
                drawStar5(ctx: ctx, cx: cx + CGFloat(ox)*sc, cy: cy + CGFloat(oy)*sc,
                          r: 3*sc, color: markColor)
            }
        case .wild:
            for (ox, oy) in [(-14.0,2.0),(10.0,-8.0),(0.0,13.0),(-6.0,19.0)] {
                let r = 4*sc
                ctx.fill(Circle().path(in: CGRect(x:cx+CGFloat(ox)*sc-r, y:cy+CGFloat(oy)*sc-r, width:r*2,height:r*2)),
                         with: .color(markColor))
            }
        case .healthy:
            ctx.fill(Path(CGRect(x:cx-16*sc, y:cy-8*sc, width:5*sc, height:18*sc)), with:.color(markColor))
            ctx.fill(Path(CGRect(x:cx+11*sc, y:cy-8*sc, width:5*sc, height:18*sc)), with:.color(markColor))
        case .sleepy:
            for (ox, oy) in [(-10.0,0.0),(10.0,-6.0)] {
                let r = 5*sc
                ctx.fill(Circle().path(in: CGRect(x:cx+CGFloat(ox)*sc-r, y:cy+CGFloat(oy)*sc-r, width:r*2,height:r*2)),
                         with: .color(markColor))
            }
        default: break
        }
    }

    private func drawStar5(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, color: Color) {
        var star = Path()
        for i in 0..<10 {
            let angle = Double(i) * .pi / 5.0 - .pi / 2.0
            let radius = i % 2 == 0 ? r : r * 0.45
            let x = cx + CGFloat(cos(angle)) * radius
            let y = cy + CGFloat(sin(angle)) * radius
            if i == 0 { star.move(to: CGPoint(x: x, y: y)) }
            else       { star.addLine(to: CGPoint(x: x, y: y)) }
        }
        star.closeSubpath()
        ctx.fill(star, with: .color(color))
    }

    // MARK: Blob path helper
    private func blobPath(pts: [CGPoint]) -> Path {
        var p = Path()
        let n = pts.count
        let first = CGPoint(x: (pts[0].x + pts[n-1].x)/2,
                            y: (pts[0].y + pts[n-1].y)/2)
        p.move(to: first)
        for i in 0..<n {
            let a = pts[i], b = pts[(i+1) % n]
            let mid = CGPoint(x: (a.x+b.x)/2, y: (a.y+b.y)/2)
            p.addQuadCurve(to: mid, control: a)
        }
        p.closeSubpath()
        return p
    }
}
