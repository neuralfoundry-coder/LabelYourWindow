import SwiftUI

struct LabelOverlayView: View {
    let label: String
    let settings: SettingsManager

    var body: some View {
        Text(label)
            .font(.system(size: settings.fontSize, weight: settings.swiftFontWeight, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .fixedSize()
    }

    private var glassBackground: some View {
        ZStack {
            // Base tint layer
            RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                .fill(.black.opacity(0.25))

            // Blur/vibrancy layer
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
