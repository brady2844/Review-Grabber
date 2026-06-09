//
//  ReviewSource.swift
//  HHG-Reviews
//
//  The ingestion abstraction. The whole app is source-agnostic: anything
//  that can produce `IncomingReview`s can feed the pipeline. Today that's
//  manual entry + CSV. Tomorrow it's ReviewTrackers / Google / Yelp adapters
//  that conform to the same protocol — no other code has to change.
//

import Foundation

/// A normalized, not-yet-persisted review coming from any source.
struct IncomingReview: Identifiable, Hashable {
    var id = UUID()
    var authorName: String
    var text: String
    var rating: Int
    var source: ReviewSourceKind
    var postedAt: Date
    var externalID: String?
}

/// Anything that can pull reviews. Async so network-backed adapters slot in
/// without changing the call site.
protocol ReviewSource {
    var kind: ReviewSourceKind { get }
    var displayName: String { get }
    func fetch() async throws -> [IncomingReview]
}

// MARK: - CSV import (works today, no integration required)

enum CSVImportError: LocalizedError {
    case empty
    case missingColumns(String)

    var errorDescription: String? {
        switch self {
        case .empty: "The file appears to be empty."
        case .missingColumns(let detail): "Couldn't find the expected columns: \(detail)."
        }
    }
}

/// Parses a CSV export of reviews. Tolerant of column order and casing.
/// Recognized headers: author/name/reviewer, rating/stars, text/review/comment,
/// source/site/channel, date/posted/created.
struct CSVReviewSource: ReviewSource {
    let kind: ReviewSourceKind = .csv
    let displayName = "CSV Import"
    let rawCSV: String

    func fetch() async throws -> [IncomingReview] {
        let rows = CSVParser.parse(rawCSV)
        guard let header = rows.first, rows.count > 1 else { throw CSVImportError.empty }

        let lower = header.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        func index(_ candidates: [String]) -> Int? {
            lower.firstIndex(where: { candidates.contains($0) })
        }

        let authorIdx = index(["author", "name", "reviewer", "customer"])
        let ratingIdx = index(["rating", "stars", "score"])
        let textIdx = index(["text", "review", "comment", "content", "body"])
        let sourceIdx = index(["source", "site", "channel", "platform"])
        let dateIdx = index(["date", "posted", "created", "published", "review date"])

        guard textIdx != nil else { throw CSVImportError.missingColumns("review text") }

        let formatter = ISO8601DateFormatter()
        let fallbackFormatters: [DateFormatter] = {
            ["yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd HH:mm:ss"].map {
                let f = DateFormatter()
                f.dateFormat = $0
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }
        }()

        func parseDate(_ s: String) -> Date {
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            if let d = formatter.date(from: trimmed) { return d }
            for f in fallbackFormatters { if let d = f.date(from: trimmed) { return d } }
            return .now
        }

        func parseSource(_ s: String) -> ReviewSourceKind {
            let t = s.lowercased()
            return ReviewSourceKind.allCases.first {
                t.contains($0.rawValue.lowercased()) || t.contains($0.displayName.lowercased())
            } ?? .csv
        }

        return rows.dropFirst().compactMap { cols -> IncomingReview? in
            func col(_ i: Int?) -> String { i.flatMap { $0 < cols.count ? cols[$0] : nil } ?? "" }
            let text = col(textIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let rating = Int(col(ratingIdx).trimmingCharacters(in: .whitespaces).prefix(1)) ?? 5
            return IncomingReview(
                authorName: col(authorIdx).isEmpty ? "Anonymous" : col(authorIdx),
                text: text,
                rating: min(5, max(1, rating)),
                source: sourceIdx == nil ? .csv : parseSource(col(sourceIdx)),
                postedAt: dateIdx == nil ? .now : parseDate(col(dateIdx)),
                externalID: nil
            )
        }
    }
}

/// Minimal RFC-4180-ish CSV parser that handles quoted fields and newlines.
enum CSVParser {
    static func parse(_ input: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        let chars = Array(input)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { inQuotes = false }
                } else { field.append(c) }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": row.append(field); field = ""
                case "\n", "\r":
                    if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
                    row.append(field); field = ""
                    if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                    row = []
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}

// MARK: - Future integration adapters (stubbed)
//
// These conform to the same `ReviewSource` protocol. When the company grants
// API access, fill in `fetch()` — nothing else in the app changes.

struct ReviewTrackersSource: ReviewSource {
    let kind: ReviewSourceKind = .reviewTrackers
    let displayName = "ReviewTrackers"
    var apiKey: String = ""

    func fetch() async throws -> [IncomingReview] {
        // TODO: call https://api.reviewtrackers.com once API access is granted.
        []
    }
}

struct GoogleBusinessSource: ReviewSource {
    let kind: ReviewSourceKind = .google
    let displayName = "Google Business Profile"
    var accountToken: String = ""

    func fetch() async throws -> [IncomingReview] {
        // TODO: Google Business Profile API (requires OAuth + location id).
        []
    }
}

struct YelpSource: ReviewSource {
    let kind: ReviewSourceKind = .yelp
    let displayName = "Yelp"
    var businessID: String = ""

    func fetch() async throws -> [IncomingReview] {
        // TODO: Yelp Fusion API.
        []
    }
}
