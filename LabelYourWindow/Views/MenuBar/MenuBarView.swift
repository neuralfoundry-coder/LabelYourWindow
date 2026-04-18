import SwiftUI

struct MenuBarView: View {
    let appDelegate: AppDelegate

    @State private var editingLabel: String = ""
    @State private var isEditing: Bool = false

    private var settings: SettingsManager { appDelegate.settings }
    private var windowObserver: WindowObserver { appDelegate.windowObserver }
    private var labelManager: LabelManager { appDelegate.labelManager }
    private var overlayManager: OverlayManager { appDelegate.overlayManager }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            windowSection
            Divider()
            modeSection
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 280)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("LabelYourWindow")
                .font(.headline)
            Spacer()
            Toggle("", isOn: Bindable(settings).isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    // MARK: - Window & Label Section

    @ViewBuilder
    private var windowSection: some View {
        if let window = windowObserver.currentWindow {
            VStack(alignment: .leading, spacing: 8) {
                // App info
                HStack(spacing: 6) {
                    Image(systemName: "macwindow")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(window.appName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Current label display / edit
                if isEditing {
                    editingSection(for: window)
                } else {
                    displaySection(for: window)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        } else {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("No active window")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func displaySection(for window: WindowInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Current label
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text(labelManager.currentLabel.isEmpty ? "No label" : labelManager.currentLabel)
                    .font(.body)
                    .lineLimit(2)
                Spacer()
            }

            // Source badge
            if let assignment = labelManager.currentAssignment {
                HStack(spacing: 4) {
                    Text(assignment.source == .windowLevel ? "Window" : assignment.source == .manual ? "Custom" : assignment.source == .rule ? "Rule" : "Auto")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(assignment.source == .manual ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        )
                    Spacer()
                }
            }

            // Edit button
            Button {
                editingLabel = labelManager.currentLabel
                isEditing = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Label")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
    }

    private func editingSection(for window: WindowInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Label")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Enter label text...", text: $editingLabel)
                .textFieldStyle(.roundedBorder)
                .onSubmit { saveLabel(for: window) }

            HStack(spacing: 6) {
                Button("Save") { saveLabel(for: window) }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)

                Button("Cancel") { isEditing = false }
                    .controlSize(.small)

                Spacer()

                if labelManager.currentAssignment?.source == .manual {
                    Button("Reset to Auto") {
                        labelManager.clearManualLabel(for: window)
                        isEditing = false
                        refreshOverlay(for: window)
                    }
                    .controlSize(.small)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Mode Section

    private var modeSection: some View {
        HStack(spacing: 8) {
            Button {
                settings.displayMode = settings.displayMode == .pinned ? .fadeAway : .pinned
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: settings.displayMode == .pinned ? "pin.fill" : "pin.slash")
                    Text(settings.displayMode == .pinned ? "Pinned" : "Fade Away")
                }
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .tint(settings.displayMode == .pinned ? .blue : nil)

            Spacer()

            SettingsLink {
                Text("Settings...")
            }
            .controlSize(.small)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Hover over label to drag")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .controlSize(.small)
        }
    }

    // MARK: - Actions

    private func saveLabel(for window: WindowInfo) {
        let trimmed = editingLabel.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            labelManager.clearManualLabel(for: window)
        } else {
            labelManager.setManualLabel(trimmed, for: window)
        }
        isEditing = false
        refreshOverlay(for: window)
    }

    private func refreshOverlay(for window: WindowInfo) {
        let assignment = labelManager.labelForWindow(window)
        let isPinned = assignment.isPinned || settings.displayMode == .pinned
        overlayManager.showLabel(assignment.label, for: window, isPinned: isPinned)
    }
}
