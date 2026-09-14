import SwiftUI

/// Modern minimal settings interface inspired by shadcn/ui and Superwhisper.
/// Neutral zinc palette, crisp typography, clean cards, and zero skeuomorphic clutter.
struct ModernSettingsView: View {
    @Bindable var controller: DictationController
    @State private var settings = Settings.shared

    // shadcn-inspired zinc tokens
    private let bgMain = Color(red: 0.035, green: 0.035, blue: 0.043) // #09090b
    private let bgCard = Color(red: 0.094, green: 0.094, blue: 0.106) // #18181b
    private let bgSubtle = Color(red: 0.153, green: 0.153, blue: 0.165) // #27272a
    private let borderSubtle = Color(red: 0.153, green: 0.153, blue: 0.165) // #27272a
    private let textPrimary = Color(red: 0.957, green: 0.957, blue: 0.961) // #f4f4f5
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667) // #a1a1aa
    private let accentOrange = Color(red: 0.976, green: 0.451, blue: 0.086) // #f97316

    var body: some View {
        ZStack {
            bgMain.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    // Push to Talk / Hotkey
                    hotkeyCard

                    // Model Selection
                    modelCard

                    // Formatting & Options
                    optionsCard

                    // Privacy Badge
                    privacyBadge
                }
                .padding(24)
            }
        }
        .frame(width: 580, height: 640)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(borderSubtle, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("HamsFlow")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(textPrimary)

                    Text("v1.0")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(bgSubtle, in: Capsule())
                        .foregroundStyle(textMuted)

                    Text("100% LOCAL")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentOrange.opacity(0.15), in: Capsule())
                        .foregroundStyle(accentOrange)
                }

                Text("Local voice dictation for macOS · Powered by Apple Neural Engine")
                    .font(.system(size: 12))
                    .foregroundStyle(textMuted)
            }

            Spacer()
        }
        .padding(.bottom, 4)
    }

    // MARK: - Hotkey Card

    private var hotkeyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Trigger Shortcut", icon: "keyboard", subtitle: "Hold to speak, or tap to toggle on/off")

            // Presets
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(PushToTalkShortcut.presets, id: \.self) { preset in
                        let isSelected = settings.pushToTalkShortcut == preset
                        Button {
                            settings.pushToTalkShortcut = preset
                            controller.reloadHotkey()
                        } label: {
                            Text(preset.displayName)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(isSelected ? textPrimary : textMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isSelected ? bgSubtle : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(isSelected ? textPrimary.opacity(0.4) : borderSubtle, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Custom Hotkey Recorder
                HotkeyRecorderView(currentShortcut: settings.pushToTalkShortcut) { newShortcut in
                    settings.pushToTalkShortcut = newShortcut
                    controller.reloadHotkey()
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(accentOrange)

                Text("Hybrid Trigger: Hold key down for Push-to-Talk, or quick-tap (<350ms) to toggle continuous recording.")
                    .font(.system(size: 11))
                    .foregroundStyle(textMuted)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Model Card

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Speech Engine", icon: "cpu", subtitle: "Runs locally on your Mac's Apple Silicon")

            HStack(spacing: 12) {
                engineOption(
                    title: "Apple Speech",
                    badge: "STREAMING",
                    description: "Instant real-time transcription while speaking. Zero model download required.",
                    choice: .apple
                )

                engineOption(
                    title: "Parakeet TDT",
                    badge: "COREML",
                    description: "High-accuracy batch model running on the Neural Engine. Resolves on release (~470MB).",
                    choice: .parakeet
                )
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func engineOption(title: String, badge: String, description: String, choice: SpeechEngineChoice) -> some View {
        let isSelected = settings.engine == choice
        return Button {
            settings.engine = choice
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? textPrimary : textMuted)

                    Spacer()

                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? accentOrange.opacity(0.2) : bgSubtle, in: Capsule())
                        .foregroundStyle(isSelected ? accentOrange : textMuted)
                }

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(textMuted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? bgSubtle.opacity(0.8) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? textPrimary.opacity(0.5) : borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Options Card

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Text & Audio Settings", icon: "slider.horizontal.3", subtitle: "Wispr Flow & Superwhisper formatting")

            VStack(spacing: 12) {
                toggleRow(
                    title: "Smart Text Cleanup",
                    subtitle: "Strips filler words ('um', 'uh', 'like') and fixes punctuation before typing.",
                    isOn: $settings.cleanupEnabled
                )

                Divider().background(borderSubtle)

                toggleRow(
                    title: "Audio Feedback",
                    subtitle: "Plays subtle mechanical tick when recording starts and pops when complete.",
                    isOn: $settings.soundEnabled
                )

                Divider().background(borderSubtle)

                toggleRow(
                    title: "Compare Mode",
                    subtitle: "Runs both Apple and Parakeet concurrently side-by-side to benchmark accuracy.",
                    isOn: $settings.compareMode
                )
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(textPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(textMuted)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    // MARK: - Privacy Badge

    private var privacyBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.green)

            VStack(alignment: .leading, spacing: 1) {
                Text("100% Private & Air-Gapped")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textPrimary)

                Text("Your audio never touches the cloud or external servers. Complete peace of mind.")
                    .font(.system(size: 11))
                    .foregroundStyle(textMuted)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.green.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentOrange)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(textMuted)
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(bgCard)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(borderSubtle, lineWidth: 1)
            )
    }
}
