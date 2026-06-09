//
//  AppModels.swift
//  HHG-Reviews
//
//  The multi-tenant data model. Even though v1 runs on a local SwiftData
//  store, these shapes are designed to map cleanly onto a cloud backend
//  later (Organization -> Location -> Employee/Review/Rule/Contest).
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

/// Where a review originated. The app is source-agnostic: every incoming
/// review is normalized into a `Review` regardless of which integration
/// produced it. New sources just add a case + an adapter (see ReviewSource).
enum ReviewSourceKind: String, Codable, CaseIterable, Identifiable {
    case manual
    case csv
    case google
    case yelp
    case facebook
    case tripadvisor
    case reviewTrackers

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: "Manual"
        case .csv: "CSV Import"
        case .google: "Google"
        case .yelp: "Yelp"
        case .facebook: "Facebook"
        case .tripadvisor: "Tripadvisor"
        case .reviewTrackers: "ReviewTrackers"
        }
    }

    var symbol: String {
        switch self {
        case .manual: "square.and.pencil"
        case .csv: "tablecells"
        case .google: "globe"
        case .yelp: "fork.knife"
        case .facebook: "person.2.fill"
        case .tripadvisor: "binoculars.fill"
        case .reviewTrackers: "chart.bar.doc.horizontal"
        }
    }

    var tint: Color {
        switch self {
        case .manual: .gray
        case .csv: .teal
        case .google: .blue
        case .yelp: .red
        case .facebook: .indigo
        case .tripadvisor: .green
        case .reviewTrackers: .purple
        }
    }
}

/// Which review field a rule condition inspects.
enum ReviewField: String, Codable, CaseIterable, Identifiable {
    case text
    case authorName
    case rating
    case source

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .text: "Review text"
        case .authorName: "Author name"
        case .rating: "Star rating"
        case .source: "Source"
        }
    }
}

/// Comparison operators a rule condition can use.
enum ConditionOperator: String, Codable, CaseIterable, Identifiable {
    case contains
    case notContains
    case equals
    case greaterThanOrEqual
    case lessThanOrEqual

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .contains: "contains"
        case .notContains: "does not contain"
        case .equals: "is"
        case .greaterThanOrEqual: "is at least"
        case .lessThanOrEqual: "is at most"
        }
    }
}

/// How a rule's multiple conditions combine.
enum RuleMatch: String, Codable, CaseIterable, Identifiable {
    case all
    case any
    var id: String { rawValue }
    var displayName: String { self == .all ? "ALL" : "ANY" }
}

/// One condition inside a rule. Stored as a Codable value type inside the
/// SwiftData `Rule` model.
struct RuleCondition: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var field: ReviewField = .text
    var op: ConditionOperator = .contains
    var value: String = ""
}

/// The contest metric — what we're ranking employees by.
enum ContestMetric: String, Codable, CaseIterable, Identifiable {
    case reviewCount
    case fiveStarCount
    case averageRating

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .reviewCount: "Total reviews"
        case .fiveStarCount: "5-star reviews"
        case .averageRating: "Average rating"
        }
    }
}

// MARK: - Organization

@Model
final class Organization {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Location.organization)
    var locations: [Location] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
    }
}

// MARK: - Location

@Model
final class Location {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    var organization: Organization?

    @Relationship(deleteRule: .cascade, inverse: \Employee.location)
    var employees: [Employee] = []

    @Relationship(deleteRule: .cascade, inverse: \Review.location)
    var reviews: [Review] = []

    @Relationship(deleteRule: .cascade, inverse: \Rule.location)
    var rules: [Rule] = []

    @Relationship(deleteRule: .cascade, inverse: \Contest.location)
    var contests: [Contest] = []

    init(name: String, organization: Organization? = nil) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.organization = organization
    }
}

// MARK: - Employee

@Model
final class Employee {
    var id: UUID = UUID()
    var name: String = ""
    var role: String = "Server"
    /// Hex string driving the employee's avatar gradient.
    var colorHex: String = "11A8CD"
    var createdAt: Date = Date()
    var isActive: Bool = true

    var location: Location?

    @Relationship(deleteRule: .nullify, inverse: \Review.creditedEmployee)
    var creditedReviews: [Review] = []

    init(name: String, role: String = "Server", colorHex: String = "11A8CD", location: Location? = nil) {
        self.id = UUID()
        self.name = name
        self.role = role
        self.colorHex = colorHex
        self.location = location
        self.createdAt = .now
    }

    /// Up to two-letter initials for avatar fallback.
    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

// MARK: - Review

@Model
final class Review {
    var id: UUID = UUID()
    /// Stable id from the originating system, if any (dedupe key).
    var externalID: String?
    var authorName: String = ""
    var text: String = ""
    var rating: Int = 5
    var sourceRaw: String = ReviewSourceKind.manual.rawValue
    var postedAt: Date = Date()
    var importedAt: Date = Date()
    /// Set by the rule engine or a manager. Nil = unassigned.
    var creditedEmployee: Employee?
    /// True once a human has confirmed/overridden the auto-assignment.
    var isManuallyAssigned: Bool = false
    var tags: [String] = []

    var location: Location?

    init(
        authorName: String,
        text: String,
        rating: Int,
        source: ReviewSourceKind,
        postedAt: Date,
        externalID: String? = nil,
        location: Location? = nil
    ) {
        self.id = UUID()
        self.authorName = authorName
        self.text = text
        self.rating = rating
        self.sourceRaw = source.rawValue
        self.postedAt = postedAt
        self.importedAt = .now
        self.externalID = externalID
        self.location = location
    }

    var source: ReviewSourceKind {
        get { ReviewSourceKind(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}

// MARK: - Rule

@Model
final class Rule {
    var id: UUID = UUID()
    var name: String = ""
    var isEnabled: Bool = true
    /// Lower runs first; first matching credit rule wins.
    var priority: Int = 0
    var matchRaw: String = RuleMatch.all.rawValue
    var conditions: [RuleCondition] = []
    /// The employee this rule credits, by stable id. Nil = tag-only rule.
    var creditEmployeeID: UUID?
    /// Tags this rule applies on match.
    var appliesTags: [String] = []
    var createdAt: Date = Date()

    var location: Location?

    init(
        name: String,
        priority: Int = 0,
        match: RuleMatch = .all,
        conditions: [RuleCondition] = [],
        creditEmployeeID: UUID? = nil,
        appliesTags: [String] = [],
        location: Location? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.priority = priority
        self.matchRaw = match.rawValue
        self.conditions = conditions
        self.creditEmployeeID = creditEmployeeID
        self.appliesTags = appliesTags
        self.location = location
        self.createdAt = .now
    }

    var match: RuleMatch {
        get { RuleMatch(rawValue: matchRaw) ?? .all }
        set { matchRaw = newValue.rawValue }
    }
}

// MARK: - Contest

@Model
final class Contest {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var prizeAmount: Double = 100
    var metricRaw: String = ContestMetric.reviewCount.rawValue
    var isActive: Bool = true

    var location: Location?

    init(
        name: String,
        startDate: Date,
        endDate: Date,
        prizeAmount: Double = 100,
        metric: ContestMetric = .reviewCount,
        location: Location? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.prizeAmount = prizeAmount
        self.metricRaw = metric.rawValue
        self.location = location
    }

    var metric: ContestMetric {
        get { ContestMetric(rawValue: metricRaw) ?? .reviewCount }
        set { metricRaw = newValue.rawValue }
    }

    var contains: ClosedRange<Date> { startDate...endDate }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: endDate).day ?? 0)
    }
}
