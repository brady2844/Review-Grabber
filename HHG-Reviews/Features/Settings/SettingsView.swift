//
//  SettingsView.swift
//  HHG-Reviews
//
//  Data sources, CSV import, team, and contest management.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    let location: Location
    @Environment(\.modelContext) private var context
    @State private var showImport = false
    @State private var importResult: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Org / location header
                VStack(spacing: 6) {
                    Text(location.organization?.name ?? "Organization")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.aqua)
                    Text(location.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(location.employees.count) team members · \(location.reviews.count) reviews")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .glassCard()

                // Data sources
                SectionHeader("Data sources")
                VStack(spacing: 10) {
                    SourceRow(kind: .csv, status: .active) { showImport = true }
                    SourceRow(kind: .manual, status: .active, action: nil)
                    SourceRow(kind: .google, status: .comingSoon, action: nil)
                    SourceRow(kind: .yelp, status: .comingSoon, action: nil)
                    SourceRow(kind: .reviewTrackers, status: .comingSoon, action: nil)
                }

                // Tools
                SectionHeader("Tools")
                VStack(spacing: 10) {
                    ToolRow(icon: "arrow.triangle.2.circlepath", tint: Palette.aqua,
                            title: "Re-run all rules",
                            subtitle: "Re-attribute every review") {
                        IngestionService.reapplyRules(in: location)
                    }
                    ToolRow(icon: "trash", tint: .red,
                            title: "Reset demo data",
                            subtitle: "Wipe and reseed The Catch") {
                        resetDemo()
                    }
                }

                if let importResult {
                    Text(importResult)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.aqua)
                        .padding(.top, 4)
                }

                Color.clear.frame(height: 24)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) {
            HStack {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal).padding(.vertical, 12)
        }
        .sheet(isPresented: $showImport) {
            CSVImportSheet(location: location) { count in
                importResult = "Imported \(count) new review\(count == 1 ? "" : "s")."
            }
            .presentationDetents([.large])
            .presentationBackground(.ultraThinMaterial)
        }
    }

    private func resetDemo() {
        for r in location.reviews { context.delete(r) }
        for e in location.employees { context.delete(e) }
        for rule in location.rules { context.delete(rule) }
        for c in location.contests { context.delete(c) }
        if let org = location.organization { context.delete(org) }
        context.delete(location)
        try? context.save()
        SampleData.seed(context)
    }
}

// MARK: - Pieces

private struct SectionHeader: View {
    let title: String
    init(_ t: String) { title = t }
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
                .tracking(1.2)
            Spacer()
        }
        .padding(.top, 6)
    }
}

private enum SourceStatus { case active, comingSoon }

private struct SourceRow: View {
    let kind: ReviewSourceKind
    let status: SourceStatus
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(kind.tint)
                    .frame(width: 38, height: 38)
                    .background(kind.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(kind.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                switch status {
                case .active:
                    if action != nil {
                        Text("Import")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Gradients.brand, in: Capsule())
                    } else {
                        StatusDot(text: "Active", color: Palette.aqua)
                    }
                case .comingSoon:
                    StatusDot(text: "Soon", color: Palette.textTertiary)
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .disabled(action == nil && status == .active)
    }
}

private struct StatusDot: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}

private struct ToolRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(12)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CSV import sheet

private struct CSVImportSheet: View {
    let location: Location
    let onDone: (Int) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var error: String?

    private let placeholder = "author,rating,text,source,date\nJane D,5,\"Brady was amazing!\",Google,2026-06-01"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste a CSV export. We auto-detect columns for author, rating, text, source, and date — then run your rules on every row.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal)

                TextEditor(text: $text)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassCard(cornerRadius: 16)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(Palette.textTertiary)
                                .padding(18)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal)

                if let error {
                    Text(error)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .padding(.top, 12)
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { Task { await runImport() } }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func runImport() async {
        do {
            let incoming = try await CSVReviewSource(rawCSV: text).fetch()
            let added = IngestionService.ingest(incoming, into: location, context: context)
            onDone(added)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
