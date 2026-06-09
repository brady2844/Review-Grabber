//
//  ReviewsView.swift
//  HHG-Reviews
//
//  The review feed: every incoming review with its source, rating, tags, and
//  who got credit. Managers can tap to reassign or add reviews manually.
//

import SwiftUI
import SwiftData

struct ReviewsView: View {
    let location: Location

    @Query private var reviews: [Review]
    @Environment(\.modelContext) private var context
    @State private var showAdd = false
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case unassigned = "Unassigned"
        case fiveStar = "5★"
        var id: String { rawValue }
    }

    init(location: Location) {
        self.location = location
        let id = location.persistentModelID
        _reviews = Query(
            filter: #Predicate<Review> { $0.location?.persistentModelID == id },
            sort: \Review.postedAt, order: .reverse
        )
    }

    private var filtered: [Review] {
        switch filter {
        case .all: reviews
        case .unassigned: reviews.filter { $0.creditedEmployee == nil }
        case .fiveStar: reviews.filter { $0.rating == 5 }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 4)

                ForEach(filtered) { review in
                    ReviewCard(review: review, employees: location.employees) { employee in
                        review.creditedEmployee = employee
                        review.isManuallyAssigned = true
                    }
                }
                .padding(.horizontal)

                if filtered.isEmpty {
                    Text("Nothing here yet.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 60)
                }
                Color.clear.frame(height: 24)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reviews")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(reviews.count) total")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(Gradients.brand, in: Circle())
                        .shadow(color: Palette.aqua.opacity(0.4), radius: 8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showAdd) {
            AddReviewSheet(location: location)
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

// MARK: - Review card

private struct ReviewCard: View {
    let review: Review
    let employees: [Employee]
    let onAssign: (Employee?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SourceChip(source: review.source)
                Spacer()
                StarRating(rating: review.rating, size: 12)
            }

            Text(review.text)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Palette.textPrimary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(review.authorName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
                Text("· \(review.postedAt.formatted(.dateTime.month().day()))")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
                Spacer()

                Menu {
                    Button("Unassigned") { onAssign(nil) }
                    Divider()
                    ForEach(employees) { emp in
                        Button(emp.name) { onAssign(emp) }
                    }
                } label: {
                    if let emp = review.creditedEmployee {
                        HStack(spacing: 6) {
                            EmployeeAvatar(employee: emp, size: 22)
                            Text(emp.name.split(separator: " ").first.map(String.init) ?? emp.name)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            if review.isManuallyAssigned {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Palette.textTertiary)
                            }
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.white.opacity(0.06), in: Capsule())
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: "person.badge.plus")
                            Text("Assign")
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.aqua)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Palette.aqua.opacity(0.12), in: Capsule())
                    }
                }
            }

            if !review.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(review.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.aqua)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Palette.aqua.opacity(0.10), in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Add review sheet

private struct AddReviewSheet: View {
    let location: Location
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var author = ""
    @State private var text = ""
    @State private var rating = 5
    @State private var source: ReviewSourceKind = .manual

    var body: some View {
        NavigationStack {
            Form {
                Section("Review") {
                    TextField("Author", text: $author)
                    TextField("What did they say?", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Rating") {
                    Stepper(value: $rating, in: 1...5) {
                        StarRating(rating: rating, size: 16)
                    }
                }
                Section("Source") {
                    Picker("Source", selection: $source) {
                        ForEach(ReviewSourceKind.allCases) { Text($0.displayName).tag($0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let incoming = IncomingReview(
            authorName: author.isEmpty ? "Anonymous" : author,
            text: text, rating: rating, source: source, postedAt: .now
        )
        IngestionService.ingest([incoming], into: location, context: context)
        dismiss()
    }
}
