//
//  Confetti.swift
//  HHG-Reviews
//
//  A lightweight, dependency-free confetti burst rendered with Canvas +
//  TimelineView. Fire it by incrementing `trigger`.
//

import SwiftUI

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let xStart: CGFloat        // 0...1 horizontal origin
    let color: Color
    let size: CGFloat
    let delay: Double
    let drift: CGFloat         // horizontal sway amplitude
    let spin: Double           // rotations per second
    let fall: CGFloat          // vertical speed multiplier
    let isCircle: Bool
}

struct ConfettiView: View {
    var trigger: Int
    var duration: Double = 2.6

    @State private var particles: [ConfettiParticle] = []
    @State private var start = Date()

    private let palette: [Color] = [
        Palette.gold, Palette.goldDeep, Palette.aqua, Palette.cyan, .white
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                guard t < duration else { return }
                for p in particles {
                    let local = t - p.delay
                    guard local > 0 else { continue }
                    let progress = local / duration
                    let y = CGFloat(progress) * (size.height + 120) - 40
                    let x = p.xStart * size.width
                        + sin(CGFloat(local) * 3 + p.xStart * 10) * p.drift
                    let angle = local * p.spin * .pi * 2
                    let opacity = max(0, 1 - progress * 1.1)

                    var layer = context
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(angle))
                    layer.opacity = opacity
                    let rect = CGRect(x: -p.size / 2, y: -p.size / 2,
                                      width: p.size, height: p.size * (p.isCircle ? 1 : 0.6))
                    let path = p.isCircle
                        ? Path(ellipseIn: rect)
                        : Path(roundedRect: rect, cornerRadius: 1)
                    layer.fill(path, with: .color(p.color))
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: trigger) { _, _ in burst() }
    }

    private func burst() {
        particles = (0..<90).map { _ in
            ConfettiParticle(
                xStart: .random(in: 0...1),
                color: palette.randomElement()!,
                size: .random(in: 6...11),
                delay: .random(in: 0...0.5),
                drift: .random(in: 12...46),
                spin: .random(in: 0.4...1.6),
                fall: .random(in: 0.8...1.3),
                isCircle: Bool.random()
            )
        }
        start = .now
    }
}
