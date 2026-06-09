//
//  IngestionService.swift
//  HHG-Reviews
//
//  Takes normalized IncomingReviews, runs them through the rule engine for
//  auto-attribution, dedupes, and persists them against a Location.
//

import Foundation
import SwiftData

@MainActor
enum IngestionService {

    @discardableResult
    static func ingest(
        _ incoming: [IncomingReview],
        into location: Location,
        context: ModelContext
    ) -> Int {
        let rules = location.rules
        let existingKeys = Set(location.reviews.compactMap { dedupeKey(for: $0) })
        var added = 0

        for item in incoming {
            let key = dedupeKey(author: item.authorName, text: item.text, externalID: item.externalID)
            if existingKeys.contains(key) { continue }

            let review = Review(
                authorName: item.authorName,
                text: item.text,
                rating: item.rating,
                source: item.source,
                postedAt: item.postedAt,
                externalID: item.externalID,
                location: location
            )

            let result = RuleEngine.evaluate(review: review, rules: rules)
            review.tags = result.tags
            if let creditID = result.creditEmployeeID,
               let employee = location.employees.first(where: { $0.id == creditID }) {
                review.creditedEmployee = employee
            }

            context.insert(review)
            added += 1
        }
        return added
    }

    /// Re-run all rules across a location's reviews (e.g. after editing rules).
    /// Manual assignments are preserved.
    static func reapplyRules(in location: Location) {
        let rules = location.rules
        for review in location.reviews where !review.isManuallyAssigned {
            let result = RuleEngine.evaluate(review: review, rules: rules)
            review.tags = result.tags
            review.creditedEmployee = result.creditEmployeeID
                .flatMap { id in location.employees.first { $0.id == id } }
        }
    }

    private static func dedupeKey(for review: Review) -> String {
        dedupeKey(author: review.authorName, text: review.text, externalID: review.externalID)
    }

    private static func dedupeKey(author: String, text: String, externalID: String?) -> String {
        if let ext = externalID, !ext.isEmpty { return "ext:\(ext)" }
        return "\(author.lowercased())|\(text.prefix(80).lowercased())"
    }
}
