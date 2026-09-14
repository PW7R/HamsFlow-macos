import MurmurDictionary
import AppKit
import SwiftUI

/// Modern, minimal main window inspired by shadcn/ui and Linear.
/// Clean dark zinc theme, live audio equalizer visualizer, crisp typography, and zero retro clutter.
struct MainWindow: View {
    @Bindable var controller: DictationController

    @State private var section: Section = .transcriptions
    @State private var settings = Settings.shared

    // shadcn zinc tokens
    private let bgMain = Color(red: 0.035, green: 0.035, blue: 0.043) // #09090b
    private let bgCard = Color(red: 0.071, green: 0.071, blue: 0.082) // #121215
    private let bgCardHover = Color(red: 0.094, green: 0.094, blue: 0.106) // #18181b
    private let bgSubtle = Color(red: 0.153, green: 0.153, blue: 0.165) // #27272a
    private let borderSubtle = Color(red: 0.153, green: 0.153, blue: 0.165) // #27272a
    private let textPrimary = Color(red: 0.957, green: 0.957, blue: 0.961) // #f4f4f5
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667) // #a1a1aa
    private let accentRed = Color(red: 0.937, green: 0.267, blue: 0.267) // #ef4444
    private let accentEmerald = Color(red: 0.063, green: 0.725, blue: 0.506) // #10b981
    private let accentOrange = Color(red: 0.976, green: 0.451, blue: 0.086) // #f97316

    enum Section: String, CaseIterable, Identifiable {
        case transcriptions = "Transcriptions"
        case dictionary = "Dictionary"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .transcriptions: return "waveform"
            case .dictionary: return "character.book.closed"
            }
        }
    }

    var body: some View {
        ZStack {
            bgMain.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                headerBar

                Divider()
                    .overlay(borderSubtle)

                // Permissions Warning (if needed)
                permissionBanners

                // Hero Recording Card
                heroRecordingCard
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Tab Switcher
                tabSwitcher
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                // Main Content
                Group {
                    switch section {
                    case .transcriptions:
                        ModernTranscriptionList(controller: controller)
                    case .dictionary:
                        ModernDictionaryPanel()
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(minWidth: 780, minHeight: 580)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // App Branding
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(borderSubtle, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("HamsFlow")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(textPrimary)

                        Text("LOCAL")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(accentOrange.opacity(0.15), in: Capsule())
                            .foregroundStyle(accentOrange)
                    }

                    Text("On-device speech dictation")
                        .font(.system(size: 10))
                        .foregroundStyle(textMuted)
                }
            }

            Spacer()

            // Live State Pill
            stateBadge

            // Shortcut Trigger Button
            Button {
                SettingsWindowManager.shared.show(controller: controller)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10))
                    Text(settings.pushToTalkShortcut.displayName)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(bgSubtle.opacity(0.8), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(borderSubtle, lineWidth: 1)
                )
                .foregroundStyle(textPrimary)
            }
            .buttonStyle(.plain)
            .help("Push-to-talk hotkey · Click to configure")

            // Settings Button
            Button {
                SettingsWindowManager.shared.show(controller: controller)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(textMuted)
                    .frame(width: 28, height: 28)
                    .background(bgSubtle.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Preferences (⌘,)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - State Badge

    private var stateBadge: some View {
        HStack(spacing: 6) {
            switch controller.state {
            case .idle:
                Circle()
                    .fill(accentEmerald)
                    .frame(width: 6, height: 6)
                Text("Ready")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textMuted)

            case .starting:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
                Text("Starting mic…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textMuted)

            case .listening:
                Circle()
                    .fill(accentRed)
                    .frame(width: 6, height: 6)
                Text("Listening…")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentRed)

            case .finishing:
                Circle()
                    .fill(accentOrange)
                    .frame(width: 6, height: 6)
                Text("Transcribing…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentOrange)

            case .error(let msg):
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(accentRed)
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(accentRed)
                    .lineLimit(1)
                Button("Reset") { controller.clearError() }
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.plain)
                    .foregroundStyle(textPrimary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4.5)
        .background(bgCard, in: Capsule())
        .overlay(Capsule().strokeBorder(borderSubtle, lineWidth: 1))
    }

    // MARK: - Permissions Banners

    @ViewBuilder
    private var permissionBanners: some View {
        if !Permissions.hasMicrophone {
            HStack(spacing: 10) {
                Image(systemName: "mic.slash.fill")
                    .foregroundStyle(accentOrange)
                Text("Microphone permission is required for on-device voice dictation.")
                    .font(.system(size: 12))
                    .foregroundStyle(textPrimary)
                Spacer()
                Button("Grant Access") {
                    Permissions.openMicrophoneSettings()
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(accentOrange, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(accentOrange.opacity(0.12))
            .overlay(Rectangle().stroke(accentOrange.opacity(0.3), lineWidth: 1))
        }

        if !Permissions.hasAccessibility {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(accentOrange)
                Text("Accessibility permission is required for global push-to-talk hotkeys and text insertion.")
                    .font(.system(size: 12))
                    .foregroundStyle(textPrimary)
                Spacer()
                Button("Grant Access") {
                    Permissions.openAccessibilitySettings()
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(accentOrange, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(accentOrange.opacity(0.12))
            .overlay(Rectangle().stroke(accentOrange.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: - Hero Recording Card

    private var heroRecordingCard: some View {
        let isRecording = controller.state.isActive

        return HStack(spacing: 16) {
            // Main Record / Stop Toggle Button
            Button {
                controller.toggleRecording()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? accentRed : bgSubtle)
                            .frame(width: 32, height: 32)

                        if isRecording {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(textPrimary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRecording ? "Stop Recording" : "Start Dictation")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textPrimary)

                        Text(isRecording ? "Click to finalize text" : "or press \(settings.pushToTalkShortcut.displayName)")
                            .font(.system(size: 10))
                            .foregroundStyle(textMuted)
                    }
                }
                .padding(.leading, 6)
                .padding(.trailing, 16)
                .padding(.vertical, 6)
                .background(isRecording ? accentRed.opacity(0.15) : bgCardHover, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isRecording ? accentRed.opacity(0.5) : borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Dynamic Live Waveform / Audio Equalizer
            ModernWaveformBar(level: controller.level, isActive: isRecording)
                .frame(height: 38)

            Spacer()

            // Active Recording Timer or Engine Indicator
            if isRecording {
                ActiveTimerView()
            } else {
                HStack(spacing: 6) {
                    Text(settings.engine.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(textMuted)
                    if settings.cleanupEnabled {
                        Text("• Cleaned")
                            .font(.system(size: 11))
                            .foregroundStyle(accentEmerald)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(bgCard, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(borderSubtle, lineWidth: 1))
            }
        }
        .padding(14)
        .background(bgCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(Section.allCases) { item in
                let isSelected = section == item
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        section = item
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11))
                        Text(item.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? bgCardHover : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(isSelected ? borderSubtle : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(isSelected ? textPrimary : textMuted)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Active Recording Timer

private struct ActiveTimerView: View {
    @State private var startTime = Date()
    @State private var elapsed: TimeInterval = 0

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(red: 0.937, green: 0.267, blue: 0.267))
                .frame(width: 8, height: 8)

            Text(formattedTime)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.4), lineWidth: 1)
        )
        .task {
            while !Task.isCancelled {
                elapsed = Date().timeIntervalSince(startTime)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private var formattedTime: String {
        let total = Int(elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// MARK: - Modern Audio Equalizer Bar

private struct ModernWaveformBar: View {
    let level: Float
    let isActive: Bool

    private let barCount = 18

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                barView(index: index)
            }
        }
        .frame(maxWidth: 160)
    }

    private func barView(index: Int) -> some View {
        let normalizedDist = abs(Float(index) - Float(barCount) / 2.0) / (Float(barCount) / 2.0)
        let curve = max(0.2, 1.0 - (normalizedDist * 0.6))
        let targetHeight: CGFloat = isActive
            ? max(4, CGFloat(level * curve * 28) + CGFloat((index % 3) * 2))
            : 3

        return RoundedRectangle(cornerRadius: 1.5)
            .fill(isActive
                  ? (level > 0.05 ? Color(red: 0.957, green: 0.957, blue: 0.961) : Color(red: 0.4, green: 0.4, blue: 0.43))
                  : Color(red: 0.2, green: 0.2, blue: 0.22))
            .frame(width: 3.5, height: targetHeight)
            .animation(.linear(duration: 0.08), value: level)
    }
}

// MARK: - Modern Transcriptions List

private struct ModernTranscriptionList: View {
    @Bindable var controller: DictationController
    @State private var store = RunStore.shared
    @State private var query = ""
    @State private var isConfirmingClear = false

    private let bgMain = Color(red: 0.035, green: 0.035, blue: 0.043)
    private let bgCard = Color(red: 0.071, green: 0.071, blue: 0.082)
    private let borderSubtle = Color(red: 0.153, green: 0.153, blue: 0.165)
    private let textPrimary = Color(red: 0.957, green: 0.957, blue: 0.961)
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667)

    private var runs: [DictationRun] {
        let all = store.runs.reversed().map { $0 }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.text.localizedStandardContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(textMuted)

                TextField("Search transcriptions…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(textPrimary)

                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(bgCard)
            .overlay(alignment: .bottom) {
                Rectangle().fill(borderSubtle).frame(height: 1)
            }
            .padding(.horizontal, 20)

            // Transcriptions List or Empty State
            if runs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 32))
                        .foregroundStyle(textMuted.opacity(0.6))
                        .padding(.top, 40)

                    Text(store.runs.isEmpty ? "No transcriptions yet" : "No matches found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(textPrimary)

                    Text(store.runs.isEmpty
                         ? "Hold \(Settings.shared.pushToTalkShortcut.displayName) to speak anywhere, or click Start Dictation above."
                         : "Try a different search query.")
                        .font(.system(size: 12))
                        .foregroundStyle(textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(runs) { run in
                            ModernTranscriptionRow(run: run) {
                                withAnimation {
                                    RunLog.delete(run)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }

                // Footer Bar
                HStack {
                    Text("\(store.runs.count) recording\(store.runs.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(textMuted)

                    Spacer()

                    Button {
                        isConfirmingClear = true
                    } label: {
                        Text("Clear History")
                            .font(.system(size: 11))
                            .foregroundStyle(textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(bgCard)
                .overlay(alignment: .top) {
                    Rectangle().fill(borderSubtle).frame(height: 1)
                }
                .confirmationDialog(
                    "Delete all \(store.runs.count) recordings?",
                    isPresented: $isConfirmingClear,
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) { RunLog.clear() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This action cannot be undone.")
                }
            }
        }
    }
}

// MARK: - Modern Transcription Row

private struct ModernTranscriptionRow: View {
    let run: DictationRun
    let onDelete: () -> Void

    @State private var didCopy = false
    @State private var isHovering = false

    private let bgCard = Color(red: 0.071, green: 0.071, blue: 0.082)
    private let bgCardHover = Color(red: 0.094, green: 0.094, blue: 0.106)
    private let bgSubtle = Color(red: 0.153, green: 0.153, blue: 0.165)
    private let borderSubtle = Color(red: 0.153, green: 0.153, blue: 0.165)
    private let textPrimary = Color(red: 0.957, green: 0.957, blue: 0.961)
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667)
    private let accentEmerald = Color(red: 0.063, green: 0.725, blue: 0.506)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Engine, Timers, Actions
            HStack(spacing: 8) {
                Text(run.engine)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(bgSubtle, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(textMuted)

                Text(String(format: "%.1fs audio", run.audioSeconds))
                    .font(.system(size: 10))
                    .foregroundStyle(textMuted)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundStyle(textMuted.opacity(0.4))

                Text(String(format: "%.2fs speed", run.processSeconds))
                    .font(.system(size: 10))
                    .foregroundStyle(textMuted)

                Spacer()

                Text(run.date, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(textMuted.opacity(0.7))

                // Copy Button
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(run.text, forType: .string)
                    didCopy = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        didCopy = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9, weight: .bold))
                        Text(didCopy ? "Copied" : "Copy")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(didCopy ? accentEmerald.opacity(0.2) : bgSubtle, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(didCopy ? accentEmerald : borderSubtle, lineWidth: 1)
                    )
                    .foregroundStyle(didCopy ? accentEmerald : textPrimary)
                }
                .buttonStyle(.plain)

                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(textMuted)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0)
                .help("Delete transcription")
            }

            // Body Text
            Text(run.text)
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Applied Corrections
            if let corrections = run.corrections, !corrections.isEmpty {
                HStack(spacing: 6) {
                    Text("Corrected:")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.976, green: 0.451, blue: 0.086))

                    ForEach(corrections, id: \.self) { c in
                        HStack(spacing: 4) {
                            Text(c.from)
                                .strikethrough()
                                .font(.system(size: 9))
                                .foregroundStyle(textMuted)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 7))
                                .foregroundStyle(textMuted)
                            Text(c.to)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(textPrimary)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(bgSubtle, in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(isHovering ? bgCardHover : bgCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(borderSubtle, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
    }
}

// MARK: - Modern Dictionary Panel

private struct ModernDictionaryPanel: View {
    @State private var store = DictionaryStore.shared
    @State private var query = ""
    @State private var editing: DictionaryEntry?
    @State private var isAdding = false

    private let bgMain = Color(red: 0.035, green: 0.035, blue: 0.043)
    private let bgCard = Color(red: 0.071, green: 0.071, blue: 0.082)
    private let bgCardHover = Color(red: 0.094, green: 0.094, blue: 0.106)
    private let bgSubtle = Color(red: 0.153, green: 0.153, blue: 0.165)
    private let borderSubtle = Color(red: 0.153, green: 0.153, blue: 0.165)
    private let textPrimary = Color(red: 0.957, green: 0.957, blue: 0.961)
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667)

    private var entries: [DictionaryEntry] { store.filtered(by: query) }

    var body: some View {
        VStack(spacing: 0) {
            // Search & Add Bar
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(textMuted)

                    TextField("Search custom dictionary…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(textPrimary)
                }

                Spacer()

                Button {
                    isAdding = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add Word")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(textPrimary, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(bgMain)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(bgCard)
            .overlay(alignment: .bottom) {
                Rectangle().fill(borderSubtle).frame(height: 1)
            }
            .padding(.horizontal, 20)

            // Content or Empty
            if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 32))
                        .foregroundStyle(textMuted.opacity(0.6))
                        .padding(.top, 40)

                    Text(store.entries.isEmpty ? "No dictionary words yet" : "No matching words")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(textPrimary)

                    Text(store.entries.isEmpty
                         ? "Add custom technical terms, acronyms, or misheard words so HamsFlow always types them right."
                         : "Try a different search term.")
                        .font(.system(size: 12))
                        .foregroundStyle(textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(entries) { entry in
                            ModernDictionaryRow(
                                entry: entry,
                                onEdit: { editing = entry },
                                onToggle: {
                                    var updated = entry
                                    updated.isEnabled.toggle()
                                    store.update(updated)
                                },
                                onDelete: { store.delete(entry) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }

                // Footer
                HStack {
                    Text("\(store.entries.count) custom rule\(store.entries.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(textMuted)

                    Spacer()

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([DictionaryStore.fileURL])
                    } label: {
                        Text("Reveal dictionary.txt")
                            .font(.system(size: 11))
                            .foregroundStyle(textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(bgCard)
                .overlay(alignment: .top) {
                    Rectangle().fill(borderSubtle).frame(height: 1)
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            ModernDictionaryEditor(entry: nil) { store.add($0) }
        }
        .sheet(item: $editing) { entry in
            ModernDictionaryEditor(entry: entry) { store.update($0) }
        }
    }
}

// MARK: - Modern Dictionary Row

private struct ModernDictionaryRow: View {
    let entry: DictionaryEntry
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private let bgCard = Color(red: 0.071, green: 0.071, blue: 0.082)
    private let bgCardHover = Color(red: 0.094, green: 0.094, blue: 0.106)
    private let bgSubtle = Color(red: 0.153, green: 0.153, blue: 0.165)
    private let borderSubtle = Color(red: 0.153, green: 0.153, blue: 0.165)
    private let textPrimary = Color(red: 0.957, green: 0.957, blue: 0.961)
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667)
    private let accentEmerald = Color(red: 0.063, green: 0.725, blue: 0.506)

    var body: some View {
        HStack(spacing: 12) {
            // Status Dot
            Circle()
                .fill(entry.isEnabled ? accentEmerald : textMuted.opacity(0.4))
                .frame(width: 6, height: 6)

            // Kind Badge
            Text(entry.kind == .correction ? "REWRITE" : "VOCAB")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(bgSubtle, in: RoundedRectangle(cornerRadius: 3))
                .foregroundStyle(textMuted)

            // Hear -> Write
            if entry.kind == .correction {
                Text(entry.hear)
                    .font(.system(size: 12))
                    .foregroundStyle(textMuted)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(textMuted.opacity(0.5))
            }

            Text(entry.write)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textPrimary)

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Text("Edit")
                            .font(.system(size: 11))
                            .foregroundStyle(textMuted)
                    }
                    .buttonStyle(.plain)

                    Button(action: onToggle) {
                        Text(entry.isEnabled ? "Disable" : "Enable")
                            .font(.system(size: 11))
                            .foregroundStyle(textMuted)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isHovering ? bgCardHover : bgCard, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(borderSubtle, lineWidth: 1)
        )
        .opacity(entry.isEnabled ? 1 : 0.5)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Modern Dictionary Editor Modal

private struct ModernDictionaryEditor: View {
    let entry: DictionaryEntry?
    let onSave: (DictionaryEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: DictionaryEntry.Kind
    @State private var hear: String
    @State private var write: String

    private let bgCard = Color(red: 0.071, green: 0.071, blue: 0.082)
    private let bgSubtle = Color(red: 0.153, green: 0.153, blue: 0.165)
    private let borderSubtle = Color(red: 0.153, green: 0.153, blue: 0.165)
    private let textPrimary = Color(red: 0.957, green: 0.957, blue: 0.961)
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667)

    init(entry: DictionaryEntry?, onSave: @escaping (DictionaryEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _kind = State(initialValue: entry?.kind ?? .term)
        _hear = State(initialValue: entry?.hear ?? "")
        _write = State(initialValue: entry?.write ?? "")
    }

    private var draft: DictionaryEntry {
        DictionaryEntry(
            id: entry?.id ?? UUID(),
            kind: kind,
            write: write.trimmingCharacters(in: .whitespacesAndNewlines),
            hear: kind == .correction ? hear.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            isEnabled: entry?.isEnabled ?? true
        )
    }

    private var isValid: Bool {
        !draft.write.isEmpty && (kind == .term || !draft.hear.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry == nil ? "Add Custom Rule" : "Edit Rule")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(textPrimary)

            // Kind selector
            Picker("", selection: $kind) {
                Text("Vocabulary Term").tag(DictionaryEntry.Kind.term)
                Text("Spelling Rewrite").tag(DictionaryEntry.Kind.correction)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 12) {
                if kind == .correction {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("When speech engine hears:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(textMuted)
                        TextField("e.g. ham's flow", text: $hear)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(bgSubtle, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(borderSubtle, lineWidth: 1))
                            .foregroundStyle(textPrimary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(kind == .correction ? "Replace and write as:" : "Proper capitalization / spelling:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(textMuted)
                    TextField("e.g. HamsFlow", text: $write)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(bgSubtle, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(borderSubtle, lineWidth: 1))
                        .foregroundStyle(textPrimary)
                }
            }

            HStack(spacing: 10) {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(bgSubtle, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(textMuted)

                Button("Save") {
                    guard isValid else { return }
                    onSave(draft)
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(isValid ? textPrimary : bgSubtle, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(isValid ? Color.black : textMuted)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(bgCard)
    }
}

// MARK: - Compatibility helpers for legacy views if needed

struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 0.631, green: 0.631, blue: 0.667))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.957, green: 0.957, blue: 0.961))
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(red: 0.631, green: 0.631, blue: 0.667))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.071, green: 0.071, blue: 0.082))
    }
}

struct EmptyPanel: View {
    let label: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.957, green: 0.957, blue: 0.961))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.631, green: 0.631, blue: 0.667))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
