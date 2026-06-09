//
//  Theme.swift
//  HHG-Reviews
//
//  The design system: palette, gradients, and reusable building blocks.
//  Goal — a premium, oceanic, "real product" feel with restrained motion.
//

import SwiftUI

// MARK: - Palette

enum Palette {
    // Deep ocean background stack
    static let bg0 = Color(hex: "060F1C")
    static let bg1 = Color(hex: "0A1B2E")
    static let bg2 = Color(hex: "0C2A40")

    // Brand aqua/teal
    static let aqua = Color(hex: "2FE3C6")
    static let cyan = Color(hex: "13A8CD")
    static let blue = Color(hex: "2E7DF6")

    // Reward gold
    static let gold = Color(hex: "FFD75E")
    static let goldDeep = Color(hex: "F5A623")

    // Podium metals
    static let silver = Color(hex: "C9D6E3")
    static let bronze = Color(hex: "D98C5F")

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.4)
    static let hairline = Color.white.opacity(0.08)
}

enum Gradients {
    static let background = LinearGradient(
        colors: [Palette.bg0, Palette.bg1, Palette.bg2],
        startPoint: .top, endPoint: .bottom
    )
    static let brand = LinearGradient(
        colors: [Palette.aqua, Palette.cyan],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let gold = LinearGradient(
        colors: [Palette.gold, Palette.goldDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static func metal(forRank rank: Int) -> LinearGradient {
        switch rank {
        case 1: gold
        case 2: LinearGradient(colors: [Palette.silver, Color(hex: "8FA3B5")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
        case 3: LinearGradient(colors: [Palette.bronze, Color(hex: "A65E37")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
        default: brand
        }
    }
}

// MARK: - Color hex

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: UInt64
        switch s.count {
        case 8: (r, g, b, a) = (v >> 24 & 0xFF, v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF)
        default: (r, g, b, a) = (v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Glass surface

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 22
    var strokeOpacity: Double = 0.12

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .background(.ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(strokeOpacity), .white.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Animated counter

/// A number that counts up when it appears or when its value changes.
struct AnimatedNumber: View {
    let value: Int
    var font: Font = .system(size: 34, weight: .bold, design: .rounded)
    var gradient: LinearGradient = Gradients.brand

    @State private var displayed: Int = 0

    var body: some View {
        Text("\(displayed)")
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(displayed)))
            .foregroundStyle(gradient)
            .onAppear {
                withAnimation(.snappy(duration: 0.9)) { displayed = value }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.snappy(duration: 0.6)) { displayed = newValue }
            }
    }
}

// MARK: - Shimmer (used on the leader)

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.6)
                .offset(x: phase * geo.size.width * 1.6)
                .blendMode(.plusLighter)
            }
            .mask(content)
            .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

// MARK: - Avatar

struct EmployeeAvatar: View {
    let employee: Employee
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: employee.colorHex),
                                 Color(hex: employee.colorHex).opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Text(employee.initials)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Star rating

struct StarRating: View {
    let rating: Int
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i <= rating ? AnyShapeStyle(Gradients.gold) : AnyShapeStyle(Palette.textTertiary))
            }
        }
    }
}

// MARK: - Source chip

struct SourceChip: View {
    let source: ReviewSourceKind
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.symbol)
            Text(source.displayName)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(source.tint.opacity(0.18), in: Capsule())
        .foregroundStyle(source.tint)
        .overlay(Capsule().strokeBorder(source.tint.opacity(0.3), lineWidth: 0.5))
    }
}

// MARK: - Background

struct AppBackground: View {
    var body: some View {
        ZStack {
            Gradients.background.ignoresSafeArea()
            // Soft aqua glow top-leading
            Circle()
                .fill(Palette.cyan.opacity(0.18))
                .frame(width: 360)
                .blur(radius: 120)
                .offset(x: -120, y: -240)
            // Gold glow bottom-trailing
            Circle()
                .fill(Palette.gold.opacity(0.10))
                .frame(width: 320)
                .blur(radius: 130)
                .offset(x: 150, y: 360)
        }
    }
}
