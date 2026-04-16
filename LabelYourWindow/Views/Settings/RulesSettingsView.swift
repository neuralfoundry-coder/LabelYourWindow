import SwiftUI

struct RulesSettingsView: View {
    @Bindable var settings: SettingsManager
    @State private var selectedRuleID: UUID?
    @State private var editingRule: LabelRule?
    @State private var showingEditor = false

    var body: some View {
        VStack(spacing: 0) {
            // Rules table
            List(selection: $selectedRuleID) {
                if settings.labelRules.isEmpty {
                    Text("No rules configured. Add a rule to automatically label windows based on app name, window title, or bundle ID.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .padding(.vertical, 8)
                } else {
                    ForEach(settings.labelRules) { rule in
                        HStack {
                            Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(rule.isEnabled ? .green : .secondary)
                                .onTapGesture {
                                    toggleRule(rule)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.labelTemplate)
                                    .font(.body)
                                HStack(spacing: 4) {
                                    Text(rule.matchType.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(RoundedRectangle(cornerRadius: 3).fill(.quaternary))
                                    if rule.isRegex {
                                        Text("regex")
                                            .font(.caption)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(RoundedRectangle(cornerRadius: 3).fill(.quaternary))
                                    }
                                    Text(rule.matchPattern)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Text("Priority: \(rule.priority)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(rule.id)
                        .contentShape(Rectangle())
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()

            // Toolbar
            HStack(spacing: 8) {
                Button {
                    editingRule = LabelRule(priority: (settings.labelRules.map(\.priority).max() ?? 0) + 1)
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }

                Button {
                    if let id = selectedRuleID {
                        deleteRule(id: id)
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selectedRuleID == nil)

                Button {
                    if let id = selectedRuleID,
                       let rule = settings.labelRules.first(where: { $0.id == id }) {
                        editingRule = rule
                        showingEditor = true
                    }
                } label: {
                    Image(systemName: "pencil")
                }
                .disabled(selectedRuleID == nil)

                Spacer()

                Text("\(settings.labelRules.count) rule(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
        .sheet(isPresented: $showingEditor) {
            if let rule = editingRule {
                RuleEditorView(rule: rule) { updatedRule in
                    saveRule(updatedRule)
                    showingEditor = false
                }
            }
        }
    }

    private func toggleRule(_ rule: LabelRule) {
        var rules = settings.labelRules
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].isEnabled.toggle()
            settings.labelRules = rules
        }
    }

    private func deleteRule(id: UUID) {
        var rules = settings.labelRules
        rules.removeAll { $0.id == id }
        settings.labelRules = rules
        selectedRuleID = nil
    }

    private func saveRule(_ rule: LabelRule) {
        var rules = settings.labelRules
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
        settings.labelRules = rules
    }
}

// MARK: - Rule Editor Sheet

struct RuleEditorView: View {
    @State var rule: LabelRule
    var onSave: (LabelRule) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(rule.labelTemplate.isEmpty ? "New Rule" : "Edit Rule")
                .font(.headline)

            Form {
                Picker("Match by", selection: $rule.matchType) {
                    ForEach(LabelRule.MatchType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                TextField("Pattern", text: $rule.matchPattern)
                    .textFieldStyle(.roundedBorder)

                Toggle("Use regex", isOn: $rule.isRegex)

                TextField("Label template", text: $rule.labelTemplate)
                    .textFieldStyle(.roundedBorder)

                Text("Available placeholders: {title}, {app}, {bundle}")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Priority")
                    Stepper(value: $rule.priority, in: 0...100) {
                        Text("\(rule.priority)")
                            .monospacedDigit()
                    }
                }

                Toggle("Enabled", isOn: $rule.isEnabled)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    onSave(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(rule.matchPattern.isEmpty || rule.labelTemplate.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 380)
    }
}
