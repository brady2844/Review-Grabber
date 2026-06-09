//
//  RuleEngine.swift
//  HHG-Reviews
//
//  The Monarch-style attribution engine. Given a review and a set of rules,
//  it decides which employee gets credit (and which tags apply). Rules run
//  in priority order; the first enabled credit-rule that matches wins.
//

import Foundation

struct RuleEvaluation {
    var creditEmployeeID: UUID?
    var tags: [String]
    /// The rule that assigned credit, for explainability in the UI.
    var matchedRuleName: String?
}

enum RuleEngine {

    /// Evaluate a single review against an ordered set of rules.
    static func evaluate(review: Review, rules: [Rule]) -> RuleEvaluation {
        var tags: Set<String> = []
        var creditID: UUID?
        var matchedName: String?

        for rule in rules.filter(\.isEnabled).sorted(by: { $0.priority < $1.priority }) {
            guard matches(review: review, rule: rule) else { continue }

            tags.formUnion(rule.appliesTags)

            // First matching credit rule wins; later ones don't override.
            if creditID == nil, let credit = rule.creditEmployeeID {
                creditID = credit
                matchedName = rule.name
            }
        }

        return RuleEvaluation(
            creditEmployeeID: creditID,
            tags: Array(tags).sorted(),
            matchedRuleName: matchedName
        )
    }

    /// Does a review satisfy a rule's conditions (respecting ALL/ANY)?
    static func matches(review: Review, rule: Rule) -> Bool {
        guard !rule.conditions.isEmpty else { return false }
        switch rule.match {
        case .all: return rule.conditions.allSatisfy { matches(review: review, condition: $0) }
        case .any: return rule.conditions.contains { matches(review: review, condition: $0) }
        }
    }

    static func matches(review: Review, condition: RuleCondition) -> Bool {
        switch condition.field {
        case .text:
            return compareString(review.text, condition)
        case .authorName:
            return compareString(review.authorName, condition)
        case .source:
            return compareString(review.source.displayName, condition)
                || compareString(review.source.rawValue, condition)
        case .rating:
            return compareNumber(review.rating, condition)
        }
    }

    private static func compareString(_ haystack: String, _ condition: RuleCondition) -> Bool {
        let lhs = haystack.lowercased()
        let rhs = condition.value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rhs.isEmpty else { return false }
        switch condition.op {
        case .contains: return containsWord(lhs, rhs)
        case .notContains: return !containsWord(lhs, rhs)
        case .equals: return lhs == rhs
        case .greaterThanOrEqual, .lessThanOrEqual: return false // not meaningful for text
        }
    }

    /// Word-boundary aware contains so a rule for "Sam" doesn't match "same".
    private static func containsWord(_ haystack: String, _ needle: String) -> Bool {
        guard let range = haystack.range(of: needle) else { return false }
        let before = range.lowerBound == haystack.startIndex
            ? nil : haystack[haystack.index(before: range.lowerBound)]
        let after = range.upperBound == haystack.endIndex
            ? nil : haystack[range.upperBound]
        func isBoundary(_ ch: Character?) -> Bool {
            guard let ch else { return true }
            return !(ch.isLetter || ch.isNumber)
        }
        // Multi-word needles fall back to plain contains.
        if needle.contains(" ") { return true }
        return isBoundary(before) && isBoundary(after)
    }

    private static func compareNumber(_ value: Int, _ condition: RuleCondition) -> Bool {
        guard let target = Int(condition.value.trimmingCharacters(in: .whitespaces)) else { return false }
        switch condition.op {
        case .equals: return value == target
        case .greaterThanOrEqual: return value >= target
        case .lessThanOrEqual: return value <= target
        case .contains, .notContains: return false
        }
    }
}
