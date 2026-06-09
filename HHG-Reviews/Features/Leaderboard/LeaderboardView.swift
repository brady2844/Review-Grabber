//
//  LeaderboardView.swift
//  HHG-Reviews
//
//  The hero screen: a live, animated standings board for the active contest.
//  Tap any server to drill into their detail page. Confetti celebrates a
//  leader; tap the crown to fire it again.
//

import SwiftUI
import SwiftData

struct LeaderboardView: View {
    let location: Location

    @Query private var reviews: [Review]
    @Query private var contests: [Contest]
    @Environment(\.modelContext) private var context

    @State private var appeared = false
    @State private var confettiTrigger = 0
    @State private var celebrated = false

    init(location: Location) {
        self.location = location
        let id = location.persistentModelID
        _reviews = Query(filter: #Predicate<Review> { $0.location?.persistentModelID == id })
        _contests = Query(filter: #Predicate<Contest> { $0.location?.persistentModelID == id })
    }

    private var contest: Contest? {
        contests.first(where: \.isActive) ?? contests.first
    }

    private var metric: ContestMetric { contest?.metric ?? .reviewCount }

    private var standings: [Standing] {
        StandingsCalculator.standings(
            employees: location.employees,
            reviews: reviews,
            metric: metric,
            window: contest?.contains
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if let contest {
                            ContestHeaderCard(contest: contest, leader: standings.first?.employee)
                                .padding(.horizontal)
                        }

                        if standings.contains(where: { $0.reviewCount > 0 }) {
                            Podium(
                                standings: Array(standings.prefix(3)),
                                metric: metric,
                                allReviews: reviews,
                                window: contest?.contains,
                                onCelebrate: { confettiTrigger += 1 }
                            )
                            .padding(.horizontal)

                            VStack(spacing: 10) {
                                ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                                    NavigationLink {
                                        EmployeeDetailView(
                                            employee: standing.employee,
                                            allReviews: reviews,
                                            contestWindow: contest?.contains
                                        )
                                    } label: {
                                        StandingRow(standing: standing, metric: metric)
                                    }
                                    .buttonStyle(.plain)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 16)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.85)
                                        .delay(Double(index) * 0.05), value: appeared)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            EmptyBoard().padding(.top, 40)
                        }

                        Color.clear.frame(height: 24)
                    }
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .top) {
                    HeaderBar(title: location.name, subtitle: "Live leaderboard") {
                        confettiTrigger += 1
                    }
                }

                ConfettiView(trigger: confettiTrigger)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .navigationBarHidden(true)
            .onAppear {
                appeared = true
                if !celebrated, let leader = standings.first, leader.reviewCount > 0 {
                    celebrated = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { confettiTrigger += 1 }
                }
            }
        }
    }
}

// MARK: - Header bar

private struct HeaderBar: View {
    let title: String
    let subtitle: String
    var onTapTrophy: () -> Void
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Button(action: onTapTrophy) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(Gradients.gold)
                    .shadow(color: Palette.gold.opacity(0.5), radius: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Contest header card

private struct ContestHeaderCard: View {
    let contest: Contest
    let leader: Employee?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(contest.name.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.aqua)
                        .tracking(1.5)
                    Text(contest.metric.displayName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(Int(contest.prizeAmount))")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Gradients.gold)
                    Text("prize")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }
            }

            Divider().overlay(Palette.hairline)

            HStack(spacing: 20) {
                StatPill(value: "\(contest.daysRemaining)",
                         label: contest.daysRemaining == 1 ? "day left" : "days left",
                         icon: "clock.fill")
                if let leader {
                    Divider().frame(height: 28).overlay(Palette.hairline)
                    HStack(spacing: 8) {
                        EmployeeAvatar(employee: leader, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Leading")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textTertiary)
                            Text(leader.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(18)
        .glassCard()
    }
}

private struct StatPill: View {
    let value: String
    let label: String
    let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Palette.aqua)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }
}

// MARK: - Podium (top 3)

private struct Podium: View {
    let standings: [Standing]
    let metric: ContestMetric
    let allReviews: [Review]
    let window: ClosedRange<Date>?
    let onCelebrate: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if standings.count > 1 { column(standings[1], height: 110) }
            if let first = standings.first { column(first, height: 150) }
            if standings.count > 2 { column(standings[2], height: 86) }
        }
        .frame(maxWidth: .infinity)
    }

    private func column(_ standing: Standing, height: CGFloat) -> some View {
        PodiumColumn(
            standing: standing, metric: metric, height: height,
            allReviews: allReviews, window: window, onCelebrate: onCelebrate
        )
    }
}

private struct PodiumColumn: View {
    let standing: Standing
    let metric: ContestMetric
    let height: CGFloat
    let allReviews: [Review]
    let window: ClosedRange<Date>?
    let onCelebrate: () -> Void

    @State private var grown = false
    private var isWinner: Bool { standing.rank == 1 }

    var body: some View {
        VStack(spacing: 8) {
            if isWinner {
                Button(action: onCelebrate) {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundStyle(Gradients.gold)
                        .shadow(color: Palette.gold.opacity(0.6), radius: 6)
                        .scaleEffect(grown ? 1 : 0.4)
                        .opacity(grown ? 1 : 0)
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                EmployeeDetailView(employee: standing.employee, allReviews: allReviews, contestWindow: window)
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Gradients.metal(forRank: standing.rank))
                            .frame(width: isWinner ? 70 : 58, height: isWinner ? 70 : 58)
                            .opacity(0.25)
                            .scaleEffect(1.25)
                        EmployeeAvatar(employee: standing.employee, size: isWinner ? 64 : 52)
                            .overlay(Circle().strokeBorder(Gradients.metal(forRank: standing.rank), lineWidth: 2.5))
                    }
                    .modifier(ConditionalShimmer(active: isWinner))

                    Text(standing.employee.name.split(separator: " ").first.map(String.init) ?? standing.employee.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    AnimatedNumber(
                        value: Int(standing.score(for: metric)),
                        font: .system(size: 20, weight: .heavy, design: .rounded),
                        gradient: Gradients.metal(forRank: standing.rank)
                    )

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Gradients.metal(forRank: standing.rank).opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Gradients.metal(forRank: standing.rank).opacity(0.5), lineWidth: 1)
                        )
                        .overlay(
                            Text("\(standing.rank)")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(Gradients.metal(forRank: standing.rank))
                                .opacity(0.85)
                        )
                        .frame(height: grown ? height : 0)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(isWinner ? 0.15 : 0.05)) {
                grown = true
            }
        }
    }
}

private struct ConditionalShimmer: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.shimmer() } else { content }
    }
}

// MARK: - Standing row (full list)

private struct StandingRow: View {
    let standing: Standing
    let metric: ContestMetric

    var body: some View {
        HStack(spacing: 14) {
            Text("\(standing.rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(standing.rank <= 3 ? AnyShapeStyle(Gradients.metal(forRank: standing.rank)) : AnyShapeStyle(Palette.textSecondary))
                .frame(width: 24)

            EmployeeAvatar(employee: standing.employee, size: 42)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(standing.employee.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(standing.score(for: metric)))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(unit)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }
                ProgressBar(progress: standing.progressToLeader, rank: standing.rank)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(12)
        .glassCard(cornerRadius: 18)
    }

    private var unit: String {
        switch metric {
        case .reviewCount: "reviews"
        case .fiveStarCount: "★ reviews"
        case .averageRating: "avg"
        }
    }
}

private struct ProgressBar: View {
    let progress: Double
    let rank: Int
    @State private var animated: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(Gradients.metal(forRank: rank))
                    .frame(width: max(6, geo.size.width * animated))
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.9).delay(0.1)) {
                animated = CGFloat(progress)
            }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) { animated = CGFloat(new) }
        }
    }
}

// MARK: - Empty state

private struct EmptyBoard: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "trophy")
                .font(.system(size: 44))
                .foregroundStyle(Palette.textTertiary)
            Text("No reviews yet")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Import reviews or add them manually to start the race.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .glassCard()
        .padding(.horizontal)
    }
}
