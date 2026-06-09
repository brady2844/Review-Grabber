//
//  RulesView.swift
//  HHG-Reviews
//
//  The attribution rules — Monarch-style. Each rule scans incoming reviews
//  and credits an employee or applies tags. Toggle, edit, reorder by priority.
//

import SwiftUI
import SwiftData

struct RulesView: View {
    let location: Location

    @Query private var rules: [Rule]
    @Environment(\.modelContext) private var context
    @State private var editing: Rule?
    @State private var showNew = false

    init(location: Location) {
        self.location = location
        let id = location.persistentModelID
        _rules = Query(
            filter: #Predicate<Rule> { $0.location?.persistentModelID == id },
            sort: \Rule.priority
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                InfoBanner()
                    .padding(.horizontal)

                ForEach(rules) { rule in
                    RuleCard(rule: rule, employees: location.employees) {
                        editing = rule
                    } onToggle: {
                        rule.isEnabled.toggle()
                        IngestionService.reapplyRules(in: location)
                    }
                }
                .padding(.horizontal)

                Color.clear.frame(height: 24)
            }
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rules")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(rules.filter(\.isEnabled).count) active")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Button { showNew = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(Gradients.brand, in: Circle())
                        .shadow(color: Palette.aqua.opacity(0.4), radius: 8)
                }
            }
            .padding(.horizontal).padding(.vertical, 12)
        }
        .sheet(item: $editing) { rule in
            RuleEditor(rule: rule, location: location)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showNew) {
            RuleEditor(rule: nil, location: location)
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

private struct InfoBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.title3)
                .foregroundStyle(Gradients.brand)
            Text("Rules run top to bottom on every review. The first matching credit rule wins.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }
}

private struct RuleCard: View {
    @Bindable var rule: Rule
    let employees: [Employee]
    let onEdit: () -> Void
    let onToggle: () -> Void

    private var creditedName: String? {
        guard let id = rule.creditEmployeeID else { return nil }
        return employees.first { $0.id == id }?.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(rule.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in onToggle() }))
                    .labelsHidden()
                    .tint(Palette.aqua)
            }

            // Conditions summary
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(rule.conditions.enumerated()), id: \.element.id) { i, c in
                    HStack(spacing: 6) {
                        if i > 0 {
                            Text(rule.match.displayName)
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(Palette.gold)
                        }
                        Text(c.field.displayName)
                            .foregroundStyle(Palette.textSecondary)
                        Text(c.op.displayName)
                            .foregroundStyle(Palette.textTertiary)
                        Text("“\(c.value)”")
                            .foregroundStyle(.white)
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                }
            }

            HStack(spacing: 8) {
                if let creditedName {
                    Label(creditedName, systemImage: "arrow.right.circle.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.aqua)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Palette.aqua.opacity(0.12), in: Capsule())
                }
                ForEach(rule.appliesTags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.gold)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Palette.gold.opacity(0.12), in: Capsule())
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .padding(16)
        .glassCard()
        .opacity(rule.isEnabled ? 1 : 0.5)
    }
}

// MARK: - Rule editor

private struct RuleEditor: View {
    let existing: Rule?
    let location: Location
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var match: RuleMatch
    @State private var conditions: [RuleCondition]
    @State private var creditID: UUID?
    @State private var tagsText: String

    init(rule: Rule?, location: Location) {
        self.existing = rule
        self.location = location
        _name = State(initialValue: rule?.name ?? "")
        _match = State(initialValue: rule?.match ?? .any)
        _conditions = State(initialValue: rule?.conditions ?? [RuleCondition()])
        _creditID = State(initialValue: rule?.creditEmployeeID)
        _tagsText = State(initialValue: rule?.appliesTags.joined(separator: ", ") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Rule name", text: $name)
                }

                Section("Match") {
                    Picker("Combine conditions", selection: $match) {
                        ForEach(RuleMatch.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Conditions") {
                    ForEach($conditions) { $cond in
                        VStack(spacing: 8) {
                            Picker("Field", selection: $cond.field) {
                                ForEach(ReviewField.allCases) { Text($0.displayName).tag($0) }
                            }
                            Picker("Is", selection: $cond.op) {
                                ForEach(ConditionOperator.allCases) { Text($0.displayName).tag($0) }
                            }
                            TextField("Value", text: $cond.value)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { conditions.remove(atOffsets: $0) }

                    Button {
                        conditions.append(RuleCondition())
                    } label: {
                        Label("Add condition", systemImage: "plus.circle.fill")
                    }
                }

                Section("Then credit") {
                    Picker("Employee", selection: $creditID) {
                        Text("No one (tag only)").tag(UUID?.none)
                        ForEach(location.employees) { emp in
                            Text(emp.name).tag(Optional(emp.id))
                        }
                    }
                }

                Section("And tag (comma separated)") {
                    TextField("e.g. promoter, vip", text: $tagsText)
                }

                if existing != nil {
                    Section {
                        Button("Delete rule", role: .destructive) { delete() }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(existing == nil ? "New Rule" : "Edit Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var tags: [String] {
        tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func save() {
        if let rule = existing {
            rule.name = name
            rule.match = match
            rule.conditions = conditions
            rule.creditEmployeeID = creditID
            rule.appliesTags = tags
        } else {
            let nextPriority = (location.rules.map(\.priority).max() ?? 0) + 1
            let rule = Rule(name: name, priority: nextPriority, match: match,
                            conditions: conditions, creditEmployeeID: creditID,
                            appliesTags: tags, location: location)
            context.insert(rule)
        }
        IngestionService.reapplyRules(in: location)
        dismiss()
    }

    private func delete() {
        if let rule = existing { context.delete(rule) }
        IngestionService.reapplyRules(in: location)
        dismiss()
    }
}
