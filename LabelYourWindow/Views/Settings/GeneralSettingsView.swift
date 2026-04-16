import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: SettingsManager

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Enable LabelYourWindow", isOn: $settings.isEnabled)
                Toggle("Show label on window switch", isOn: $settings.showOnWindowSwitch)
                Toggle("Show label on app switch", isOn: $settings.showOnAppSwitch)
                Toggle("Allow dragging labels", isOn: $settings.allowDragging)
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }

            Section("Display Mode") {
                Picker("Mode", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if settings.displayMode == .fadeAway {
                    HStack {
                        Text("Display duration")
                        Spacer()
                        Slider(value: $settings.fadeDuration, in: 0.5...10, step: 0.5) {
                            Text("Duration")
                        }
                        .frame(width: 200)
                        Text("\(settings.fadeDuration, specifier: "%.1f")s")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }

                    HStack {
                        Text("Fade animation")
                        Spacer()
                        Slider(value: $settings.fadeAnimationDuration, in: 0.1...2.0, step: 0.1) {
                            Text("Fade")
                        }
                        .frame(width: 200)
                        Text("\(settings.fadeAnimationDuration, specifier: "%.1f")s")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            Section("Position") {
                Picker("Label position", selection: $settings.labelPosition) {
                    ForEach(LabelPosition.allCases, id: \.self) { pos in
                        Text(pos.displayName).tag(pos)
                    }
                }

                HStack {
                    Text("Inset from edge")
                    Spacer()
                    Slider(value: $settings.labelInset, in: 0...50, step: 2) {
                        Text("Inset")
                    }
                    .frame(width: 200)
                    Text("\(Int(settings.labelInset))pt")
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            }

            Section("Accessibility") {
                HStack {
                    Image(systemName: AccessibilityHelper.isAccessibilityEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(AccessibilityHelper.isAccessibilityEnabled ? .green : .orange)
                    Text(AccessibilityHelper.isAccessibilityEnabled ? "Accessibility access granted" : "Accessibility access required")
                    Spacer()
                    if !AccessibilityHelper.isAccessibilityEnabled {
                        Button("Grant Access") {
                            AccessibilityHelper.requestAccessibilityIfNeeded()
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
