import SwiftUI

struct LabelOverlayView: View {
    let label: String
    let settings: SettingsManager
    var isEditing: Bool = false
    var editText: Binding<String> = .constant("")
    var onCommit: () -> Void = {}
    var onCancel: () -> Void = {}

    @FocusState private var fieldFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                editingContent
            } else {
                displayContent
            }
        }
        .background {
            Group {
                if settings.useGlassEffect {
                    glassBackground
                } else {
                    solidBackground
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(isEditing ? 0.4 : 0.2), lineWidth: isEditing ? 1.0 : 0.5)
        }
        .fixedSize()
    }

    private var displayContent: some View {
        Text(label)
            .font(.system(size: settings.fontSize, weight: settings.swiftFontWeight, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
    }

    private var editingContent: some View {
        HStack(spacing: 6) {
            TextField("라벨...", text: editText)
                .font(.system(size: settings.fontSize, weight: settings.swiftFontWeight, design: .rounded))
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .frame(minWidth: 80, maxWidth: 220)
                .focused($fieldFocused)
                .onSubmit { onCommit() }
                .onKeyPress(.escape) {
                    onCancel()
                    return .handled
                }
            Button {
                onCommit()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: settings.fontSize))
            }
            .buttonStyle(.plain)
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.8))
                    .font(.system(size: settings.fontSize))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onAppear { fieldFocused = true }
    }

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                .fill(.black.opacity(0.25))

            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous))
        }
    }

    private var solidBackground: some View {
        RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
            .fill(.black.opacity(settings.backgroundOpacity))
    }
}

// MARK: - NSVisualEffectView wrapper for proper behind-window blending

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
