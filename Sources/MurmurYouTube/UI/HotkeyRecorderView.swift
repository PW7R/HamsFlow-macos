import AppKit
import Carbon.HIToolbox
import SwiftUI

/// An interactive hotkey recorder with minimal shadcn-inspired styling.
///
/// Allows recording arbitrary hotkeys: single physical modifiers (Left/Right Option, Command,
/// Control, Shift, fn), key combinations (e.g. ⌥ Space, ⌃ Space, ⌘ ⇧ D), or function keys.
struct HotkeyRecorderView: View {
    let currentShortcut: PushToTalkShortcut
    let onRecorded: (PushToTalkShortcut) -> Void

    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var pendingModifierKeyCode: UInt16?
    @State private var pendingIsFunction = false

    private let bgCard = Color(red: 0.094, green: 0.094, blue: 0.106) // #18181b
    private let bgSubtle = Color(red: 0.153, green: 0.153, blue: 0.165) // #27272a
    private let borderSubtle = Color(red: 0.2, green: 0.2, blue: 0.22)
    private let textPrimary = Color(red: 0.957, green: 0.957, blue: 0.961) // #f4f4f5
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667) // #a1a1aa
    private let accentOrange = Color(red: 0.976, green: 0.451, blue: 0.086) // #f97316

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isRecording ? accentOrange : (isCustomActive ? textPrimary : textMuted.opacity(0.4)))
                        .frame(width: 7, height: 7)

                    Text(buttonTitle)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(isRecording ? accentOrange : (isCustomActive ? textPrimary : textMuted))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isRecording ? accentOrange.opacity(0.12) : (isCustomActive ? bgSubtle : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isRecording ? accentOrange : (isCustomActive ? textPrimary.opacity(0.5) : borderSubtle),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)

            if isRecording {
                Button {
                    stopRecording()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(textMuted)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(bgSubtle)
                                .strokeBorder(borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Cancel recording")
            } else if isCustomActive {
                Text("CUSTOM ACTIVE")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(bgSubtle, in: Capsule())
                    .foregroundStyle(textMuted)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var isCustomActive: Bool {
        !PushToTalkShortcut.presets.contains(currentShortcut)
    }

    private var buttonTitle: String {
        if isRecording {
            return "PRESS KEY… (ESC TO CANCEL)"
        }
        if isCustomActive {
            return "CUSTOM: \(currentShortcut.displayName)"
        }
        return "RECORD CUSTOM HOTKEY"
    }

    // MARK: - Event Monitoring

    private func startRecording() {
        stopRecording()
        isRecording = true
        pendingModifierKeyCode = nil
        pendingIsFunction = false

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            let isKeyDown = (event.type == .keyDown)
            let keyCode = event.keyCode
            let flagsRaw = event.modifierFlags.rawValue
            let isFunction = event.modifierFlags.contains(.function)
            let chars = event.charactersIgnoringModifiers

            let consume = MainActor.assumeIsolated {
                if isKeyDown {
                    return self.handleKeyDown(keyCode: keyCode, flagsRaw: flagsRaw, characters: chars)
                } else {
                    return self.handleFlagsChanged(keyCode: keyCode, flagsRaw: flagsRaw, isFunction: isFunction)
                }
            }
            return consume ? nil : event
        }
    }

    private func stopRecording() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        pendingModifierKeyCode = nil
        pendingIsFunction = false
        isRecording = false
    }

    private func handleKeyDown(keyCode: UInt16, flagsRaw: UInt, characters: String?) -> Bool {
        guard isRecording else { return false }

        // Escape key cancels recording
        if keyCode == UInt16(kVK_Escape) && (UInt64(flagsRaw) & PushToTalkShortcut.relevantModifierMask == 0) {
            stopRecording()
            return true
        }

        let shortcut = PushToTalkShortcut.from(keyCode: keyCode, modifierFlagsRaw: flagsRaw, characters: characters)
        onRecorded(shortcut)
        stopRecording()
        return true
    }

    private func handleFlagsChanged(keyCode: UInt16, flagsRaw: UInt, isFunction: Bool) -> Bool {
        guard isRecording else { return false }

        let relevantFlags = UInt64(flagsRaw) & PushToTalkShortcut.relevantModifierMask

        if relevantFlags != 0 || isFunction {
            // Modifier key down
            pendingModifierKeyCode = keyCode
            pendingIsFunction = isFunction
        } else {
            // Modifier key released — record it if one was held
            if let heldCode = pendingModifierKeyCode,
               let shortcut = PushToTalkShortcut.from(modifierKeyCode: heldCode, isFunction: pendingIsFunction) {
                onRecorded(shortcut)
                stopRecording()
                return true
            }
            pendingModifierKeyCode = nil
            pendingIsFunction = false
        }
        return true
    }
}
