//
//  EmployeeDetailView.swift
//  HHG-Reviews
//
//  A single server's performance page: headline stats, source mix, rating
//  distribution, and their credited reviews.
//

import SwiftUI

struct EmployeeDetailView: View {
    let employee: Employee
    let allReviews: [Review]
    var contestWindow: ClosedRange<Date>?

    private var myReviews: [Review] {
        allReviews
            .filter { $0.creditedEmployee?.id == employee.id }
            .sorted { $0.postedAt > $1.postedAt }
    }

    private var weekReviews: [Review] {
        guard let window = contestWindow else { return myReviews }
        return myReviews.filter { window.contains($0.postedAt) }
    }

    private var avg: Double {
        myReviews.isEmpty ? 0 : Double(myReviews.map(\.rating).reduce(0, +)) / Double(myReviews.count)
    }

    private var sourceCounts: [(ReviewSourceKind, Int)] {
        Dictionary(grouping: myReviews, by: \.source)
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    private var ratingCounts: [Int: Int] {
        Dictionary(grouping: myReviews, by: \.rating).mapValues(\.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Hero
                VStack(spacing: 12) {
                    EmployeeAvatar(employee: employee, size: 88)
                        .shadow(color: Color(hex: employee.colorHex).opacity(0.5), radius: 14)
                    Text(employee.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(employee.role)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.top, 8)

                // Stat trio
                HStack(spacing: 12) {
                    StatBlock(value: "\(weekReviews.count)", label: "This week", tint: Palette.aqua)
                    StatBlock(value: "\(myReviews.count)", label: "All time", tint: Palette.cyan)
                    StatBlock(value: avg == 0 ? "—" : String(format: "%.1f", avg),
                              label: "Avg stars", tint: Palette.gold)
                }
                .padding(.horizontal)

                // Rating distribution
                if !myReviews.isEmpty {
                    Card(title: "Rating breakdown") {
                        VStack(spacing: 8) {
                            ForEach((1...5).reversed(), id: \.self) { star in
                                let count = ratingCounts[star] ?? 0
                                let frac = myReviews.isEmpty ? 0 : Double(count) / Double(myReviews.count)
                                HStack(spacing: 10) {
                                    HStack(spacing: 2) {
                                        Text("\(star)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Palette.gold)
                                    }
                                    .frame(width: 26, alignment: .leading)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(.white.opacity(0.07))
                                            Capsule().fill(Gradients.gold)
                                                .frame(width: max(count > 0 ? 8 : 0, geo.size.width * frac))
                                        }
                                    }
                                    .frame(height: 8)
                                    Text("\(count)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Palette.textSecondary)
                                        .frame(width: 22, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Source mix
                    Card(title: "Where they come from") {
                        FlowChips(items: sourceCounts)
                    }
                    .padding(.horizontal)
                }

                // Reviews
                HStack {
                    Text("CREDITED REVIEWS")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                        .tracking(1.2)
                    Spacer()
                }
                .padding(.horizontal)

                if myReviews.isEmpty {
                    Text("No credited reviews yet.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 30)
                } else {
                    VStack(spacing: 10) {
                        ForEach(myReviews) { review in
                            MiniReviewRow(review: review)
                        }
                    }
                    .padding(.horizontal)
                }

                Color.clear.frame(height: 24)
            }
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .navigationTitle(employee.name.split(separator: " ").first.map(String.init) ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatBlock: View {
    let value: String
    let label: String
    let tint: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 18)
    }
}

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

private struct FlowChips: View {
    let items: [(ReviewSourceKind, Int)]
    var body: some View {
        HStack {
            ForEach(items, id: \.0) { source, count in
                HStack(spacing: 5) {
                    Image(systemName: source.symbol)
                    Text("\(source.displayName) · \(count)")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(source.tint.opacity(0.16), in: Capsule())
                .foregroundStyle(source.tint)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MiniReviewRow: View {
    let review: Review
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SourceChip(source: review.source)
                Spacer()
                StarRating(rating: review.rating, size: 11)
            }
            Text(review.text)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Palette.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(review.authorName) · \(review.postedAt.formatted(.dateTime.month().day()))")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 16)
    }
}
