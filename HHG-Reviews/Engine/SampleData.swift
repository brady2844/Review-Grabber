//
//  SampleData.swift
//  HHG-Reviews
//
//  Seeds a realistic demo tenant: Hangout Hospitality Group -> The Catch,
//  with servers, a week of attributed reviews, name-matching rules, and an
//  active $100 weekly contest. Runs once on first launch.
//

import Foundation
import SwiftData

@MainActor
enum SampleData {

    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Organization>())) ?? []
        guard existing.isEmpty else { return }
        seed(context)
    }

    static func seed(_ context: ModelContext) {
        let org = Organization(name: "Hangout Hospitality Group")
        context.insert(org)

        let location = Location(name: "The Catch", organization: org)
        context.insert(location)

        // Servers with distinct avatar colors.
        let roster: [(String, String)] = [
            ("Brady Cook", "2FE3C6"),
            ("Sam Rivera", "F5A623"),
            ("Maya Chen", "2E7DF6"),
            ("Jordan Lee", "E0556B"),
            ("Tyler Brooks", "9B5DE5"),
            ("Priya Patel", "00BBF9"),
        ]
        var employees: [String: Employee] = [:]
        for (name, color) in roster {
            let e = Employee(name: name, role: "Server", colorHex: color, location: location)
            context.insert(e)
            employees[name] = e
            // Auto name-matching rule per server (the Monarch-style magic).
            let firstName = name.split(separator: " ").first.map(String.init) ?? name
            let rule = Rule(
                name: "Credit \(firstName)",
                priority: employees.count,
                match: .any,
                conditions: [
                    RuleCondition(field: .text, op: .contains, value: firstName)
                ],
                creditEmployeeID: e.id,
                location: location
            )
            context.insert(rule)
        }

        // A tag-only rule to flag glowing reviews.
        context.insert(Rule(
            name: "Tag promoters",
            priority: 100,
            match: .all,
            conditions: [RuleCondition(field: .rating, op: .greaterThanOrEqual, value: "5")],
            appliesTags: ["promoter"],
            location: location
        ))

        // Active weekly contest (this calendar week).
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? .now
        context.insert(Contest(
            name: "Weekly Review Cup",
            startDate: weekStart,
            endDate: cal.date(bySettingHour: 23, minute: 59, second: 59, of: weekEnd) ?? weekEnd,
            prizeAmount: 100,
            metric: .reviewCount,
            location: location
        ))

        // A week of reviews; many mention a server by name so rules attribute them.
        let samples: [(String, String, Int, ReviewSourceKind, Int)] = [
            ("Jennifer M.", "Brady was an absolute rockstar! Knew the whole menu and kept our drinks full.", 5, .google, 0),
            ("Marcus T.", "Great spot. Our server Sam recommended the blackened mahi — incredible.", 5, .yelp, 0),
            ("Dana K.", "Maya took amazing care of our anniversary dinner. So thoughtful!", 5, .google, 1),
            ("Chris P.", "Food was good but the wait was long. Jordan still kept us happy though.", 4, .tripadvisor, 1),
            ("Olivia R.", "Brady made our night. Best service we've had in a while.", 5, .facebook, 2),
            ("Nate W.", "Tyler was super friendly and fast. Will be back!", 5, .google, 2),
            ("Sophia L.", "Priya was wonderful and so attentive to my kids. Highly recommend.", 5, .yelp, 2),
            ("Ben H.", "Solid happy hour. Sam hooked us up with great recs.", 5, .google, 3),
            ("Grace D.", "Maya is the best! Remembered our order from last time.", 5, .google, 3),
            ("Aaron J.", "Decent but a little pricey. Brady was excellent though.", 4, .tripadvisor, 3),
            ("Lily S.", "Tyler went above and beyond for our big group. Five stars.", 5, .facebook, 4),
            ("Victor N.", "Loved it. Jordan was attentive and funny.", 5, .google, 4),
            ("Hannah B.", "Brady again! This guy deserves a raise. Perfect service.", 5, .yelp, 4),
            ("Ethan C.", "Priya made great cocktail suggestions. Lovely evening.", 5, .google, 5),
            ("Maria G.", "Sam was fantastic, super knowledgeable about the oysters.", 5, .google, 5),
            ("Ryan F.", "Good food, friendly staff. No complaints.", 4, .tripadvisor, 5),
            ("Chloe V.", "Maya delivered top-tier service yet again. A gem.", 5, .facebook, 6),
            ("Derek O.", "Brady is the reason we keep coming back. Phenomenal.", 5, .google, 6),
        ]

        let incoming: [IncomingReview] = samples.map { author, text, rating, source, daysAgo in
            let date = cal.date(byAdding: .day, value: daysAgo, to: weekStart) ?? .now
            return IncomingReview(authorName: author, text: text, rating: rating,
                                  source: source, postedAt: date)
        }

        IngestionService.ingest(incoming, into: location, context: context)

        try? context.save()
    }
}
