import SwiftUI

/// Brand palette. Minimal, warm orange accent.
enum Brand {
    static let accent = Color(red: 0.976, green: 0.451, blue: 0.086) // #f97316
    static let gradient = LinearGradient(
        colors: [accent, Color(red: 1.0, green: 0.58, blue: 0.2)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

/// Modern floating pill HUD inspired by shadcn/ui and Superwhisper.
/// Completely minimal: neutral dark background, crisp monochrome audio bars, and clean live text.
struct HUDView: View {
    @Bindable var controller: DictationController

    private let bgPill = Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.94) // #121214
    private let borderPill = Color.white.opacity(0.12)
    private let textPrimary = Color(red: 0.96, green: 0.96, blue: 0.96)
    private let textMuted = Color(red: 0.63, green: 0.63, blue: 0.67)
    private let accentOrange = Color(red: 0.98, green: 0.45, blue: 0.09) // #f97316

    var body: some View {
        HStack(spacing: 12) {
            // Recording status dot
            Circle()
                .fill(isError ? Color.red : accentOrange)
                .frame(width: 8, height: 8)

            // Dynamic Audio Waveform
            Waveform(level: controller.level, isActive: controller.state == .listening)
                .frame(width: 52, height: 20)

            // Live Transcript or Status text
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isError ? Color.red : textPrimary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.1), value: controller.transcript)

            // Minimal Brand pill
            Text("HamsFlow")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(textMuted.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 360, height: 48)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(bgPill)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(borderPill, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.35), radius: 16, y: 6)
        }
    }

    private var isError: Bool {
        if case .error = controller.state { return true }
        return false
    }

    private var label: String {
        switch controller.state {
        case .starting:
            return "Listening…"
        case .listening:
            if controller.transcript.isEmpty {
                return "Listening…"
            }
            return controller.transcript
        case .finishing:
            return controller.transcript.isEmpty ? "Transcribing…" : controller.transcript
        case .error(let message):
            return message
        case .idle:
            return ""
        }
    }
}

/// Dynamic audio level bars with clean monochrome styling.
private struct Waveform: View {
    let level: Float
    let isActive: Bool

    private static let barCount = 7
    private static let phases: [Double] = (0..<barCount).map { index in
        (Double(index) * 0.618).truncatingRemainder(dividingBy: 1)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<Self.barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(isActive ? 0.9 : 0.25))
                        .frame(width: 2.5, height: height(for: index, at: t))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func height(for index: Int, at time: TimeInterval) -> CGFloat {
        let floorHeight: CGFloat = 3
        guard isActive else { return floorHeight }

        let phase = Self.phases[index]
        let wave = sin(time * 6.0 + phase * .pi * 2)
        let amplitude = CGFloat(max(0.05, level))
        let scaled = amplitude * (0.6 + 0.4 * CGFloat(wave))
        return floorHeight + max(0, scaled) * 16
    }
}
