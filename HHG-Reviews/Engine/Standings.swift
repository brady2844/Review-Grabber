//
//  Standings.swift
//  HHG-Reviews
//
//  Pure scoring logic that turns reviews + a contest into a ranked board.
//  Kept separate from views so it's trivially testable and reusable.
//

import Foundation

struct Standing: Identifiable {
    let employee: Employee
    var reviewCount: Int
    var fiveStarCount: Int
    var averageRating: Double
    var rank: Int = 0
    /// 0...1 progress relative to the current leader, for bar widths.
    var progressToLeader: Double = 0

    var id: UUID { employee.id }

    func score(for metric: ContestMetric) -> Double {
        switch metric {
        case .reviewCount: Double(reviewCount)
        case .fiveStarCount: Double(fiveStarCount)
        case .averageRating: averageRating
        }
    }
}

enum StandingsCalculator {

    /// Build a ranked standings list for a contest window.
    static func standings(
        employees: [Employee],
        reviews: [Review],
        metric: ContestMetric,
        window: ClosedRange<Date>? = nil
    ) -> [Standing] {

        let scoped = reviews.filter { review in
            guard let window else { return true }
            return window.contains(review.postedAt)
        }

        var byEmployee: [UUID: [Review]] = [:]
        for review in scoped {
            guard let emp = review.creditedEmployee else { continue }
            byEmployee[emp.id, default: []].append(review)
        }

        var standings = employees.filter(\.isActive).map { emp -> Standing in
            let revs = byEmployee[emp.id] ?? []
            let five = revs.filter { $0.rating == 5 }.count
            let avg = revs.isEmpty ? 0 : Double(revs.map(\.rating).reduce(0, +)) / Double(revs.count)
            return Standing(
                employee: emp,
                reviewCount: revs.count,
                fiveStarCount: five,
                averageRating: avg
            )
        }

        // Sort by the contest metric, with sensible tiebreakers.
        standings.sort { a, b in
            let sa = a.score(for: metric), sb = b.score(for: metric)
            if sa != sb { return sa > sb }
            if a.fiveStarCount != b.fiveStarCount { return a.fiveStarCount > b.fiveStarCount }
            return a.reviewCount > b.reviewCount
        }

        let leaderScore = standings.first?.score(for: metric) ?? 0
        for i in standings.indices {
            standings[i].rank = i + 1
            standings[i].progressToLeader = leaderScore > 0
                ? standings[i].score(for: metric) / leaderScore
                : 0
        }
        return standings
    }
}
