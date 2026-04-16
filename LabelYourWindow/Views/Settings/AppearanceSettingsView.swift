import SwiftUI

struct AppearanceSettingsView: View {
    @Bindable var settings: SettingsManager

    private let weightNames = [
        (1, "Ultra Light"), (2, "Thin"), (3, "Light"), (4, "Regular"),
        (5, "Medium"), (6, "Semibold"), (7, "Bold"), (8, "Heavy"), (9, "Black")
    ]

    var body: some View {
        Form {
            Section("Font") {
                HStack {
                    Text("Size")
                    Spacer()
                    Slider(value: $settings.fontSize, in: 10...32, step: 1) {
                        Text("Font Size")
                    }
                    .frame(width: 200)
                    Text("\(Int(settings.fontSize))pt")
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }

                Picker("Weight", selection: $settings.fontWeight) {
                    ForEach(weightNames, id: \.0) { weight in
                        Text(weight.1).tag(weight.0)
                    }
                }
            }

            Section("Background") {
                Toggle("Glass effect (vibrancy)", isOn: $settings.useGlassEffect)

                if !settings.useGlassEffect {
                    HStack {
                        Text("Opacity")
                        Spacer()
                        Slider(value: $settings.backgroundOpacity, in: 0.1...1.0, step: 0.05) {
                            Text("Opacity")
                        }
                        .frame(width: 200)
                        Text("\(Int(settings.backgroundOpacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                HStack {
                    Text("Corner radius")
                    Spacer()
                    Slider(value: $settings.cornerRadius, in: 0...20, step: 1) {
                        Text("Radius")
                    }
                    .frame(width: 200)
                    Text("\(Int(settings.cornerRadius))pt")
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            }

            Section("Preview") {
                HStack {
                    Spacer()
                    previewLabel
                    Spacer()
                }
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var previewLabel: some View {
        Text("Sample Label Text")
            .font(.system(size: settings.fontSize, weight: settings.swiftFontWeight))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                if settings.useGlassEffect {
                    RoundedRectangle(cornerRadius: settings.cornerRadius)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: settings.cornerRadius)
                        .fill(.black.opacity(settings.backgroundOpacity))
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}
