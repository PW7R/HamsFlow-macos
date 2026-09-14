import AppKit
import Carbon.HIToolbox
import Foundation

/// Defines a push-to-talk hotkey trigger: either a dedicated physical modifier key,
/// or a key combination (modifier + key) / function key.
struct PushToTalkShortcut: Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case modifierOnly
        case keyCombo
    }

    var kind: Kind
    var keyCode: Int64
    /// Normalized modifier flags (command, option, control, shift).
    var modifierFlags: UInt64
    /// Device-dependent mask for modifier-only keys (distinguishes Left vs Right keys).
    var deviceMask: UInt64
    var displayName: String
    var shouldConsumeEvent: Bool

    // MARK: - Presets

    static let rightOption = PushToTalkShortcut(
        kind: .modifierOnly,
        keyCode: Int64(kVK_RightOption), // 61
        modifierFlags: CGEventFlags.maskAlternate.rawValue,
        deviceMask: 0x40, // NX_DEVICERALTKEYMASK
        displayName: "Right ⌥",
        shouldConsumeEvent: true
    )

    static let fn = PushToTalkShortcut(
        kind: .modifierOnly,
        keyCode: Int64(kVK_Function), // 63
        modifierFlags: CGEventFlags.maskSecondaryFn.rawValue,
        deviceMask: CGEventFlags.maskSecondaryFn.rawValue,
        displayName: "fn",
        shouldConsumeEvent: false // Swallowing fn would break fn+arrow, emoji picker, etc.
    )

    static let rightCommand = PushToTalkShortcut(
        kind: .modifierOnly,
        keyCode: Int64(kVK_RightCommand), // 54
        modifierFlags: CGEventFlags.maskCommand.rawValue,
        deviceMask: 0x10, // NX_DEVICERCMDKEYMASK
        displayName: "Right ⌘",
        shouldConsumeEvent: true
    )

    static let optionSpace = PushToTalkShortcut(
        kind: .keyCombo,
        keyCode: Int64(kVK_Space), // 49
        modifierFlags: CGEventFlags.maskAlternate.rawValue,
        deviceMask: 0,
        displayName: "⌥ Space",
        shouldConsumeEvent: true
    )

    static let controlSpace = PushToTalkShortcut(
        kind: .keyCombo,
        keyCode: Int64(kVK_Space), // 49
        modifierFlags: CGEventFlags.maskControl.rawValue,
        deviceMask: 0,
        displayName: "⌃ Space",
        shouldConsumeEvent: true
    )

    static let presets: [PushToTalkShortcut] = [
        .rightOption,
        .fn,
        .rightCommand,
        .optionSpace,
        .controlSpace,
    ]

    // MARK: - Modifiers Mask Helper

    /// The standard modifier bits we care about for key combinations.
    static let relevantModifierMask: UInt64 = (
        CGEventFlags.maskCommand.rawValue |
        CGEventFlags.maskAlternate.rawValue |
        CGEventFlags.maskControl.rawValue |
        CGEventFlags.maskShift.rawValue
    )

    // MARK: - Parsing

    /// Creates a shortcut from a single modifier key.
    static func from(modifierKeyCode keyCode: UInt16, isFunction: Bool) -> PushToTalkShortcut? {
        switch Int64(keyCode) {
        case Int64(kVK_RightOption):
            return .rightOption
        case Int64(kVK_Option): // 58, Left Option
            return PushToTalkShortcut(
                kind: .modifierOnly,
                keyCode: Int64(keyCode),
                modifierFlags: CGEventFlags.maskAlternate.rawValue,
                deviceMask: 0x20, // NX_DEVICELALTKEYMASK
                displayName: "Left ⌥",
                shouldConsumeEvent: true
            )
        case Int64(kVK_RightCommand):
            return .rightCommand
        case Int64(kVK_Command): // 55, Left Command
            return PushToTalkShortcut(
                kind: .modifierOnly,
                keyCode: Int64(keyCode),
                modifierFlags: CGEventFlags.maskCommand.rawValue,
                deviceMask: 0x08, // NX_DEVICELCMDKEYMASK
                displayName: "Left ⌘",
                shouldConsumeEvent: true
            )
        case Int64(kVK_RightControl): // 62
            return PushToTalkShortcut(
                kind: .modifierOnly,
                keyCode: Int64(keyCode),
                modifierFlags: CGEventFlags.maskControl.rawValue,
                deviceMask: 0x2000, // NX_DEVICERCTLKEYMASK
                displayName: "Right ⌃",
                shouldConsumeEvent: true
            )
        case Int64(kVK_Control): // 59, Left Control
            return PushToTalkShortcut(
                kind: .modifierOnly,
                keyCode: Int64(keyCode),
                modifierFlags: CGEventFlags.maskControl.rawValue,
                deviceMask: 0x01, // NX_DEVICELCTLKEYMASK
                displayName: "Left ⌃",
                shouldConsumeEvent: true
            )
        case Int64(kVK_Function): // 63
            return .fn
        case Int64(kVK_RightShift): // 60
            return PushToTalkShortcut(
                kind: .modifierOnly,
                keyCode: Int64(keyCode),
                modifierFlags: CGEventFlags.maskShift.rawValue,
                deviceMask: 0x04, // NX_DEVICERSHIFTKEYMASK
                displayName: "Right ⇧",
                shouldConsumeEvent: true
            )
        case Int64(kVK_Shift): // 56, Left Shift
            return PushToTalkShortcut(
                kind: .modifierOnly,
                keyCode: Int64(keyCode),
                modifierFlags: CGEventFlags.maskShift.rawValue,
                deviceMask: 0x02, // NX_DEVICELSHIFTKEYMASK
                displayName: "Left ⇧",
                shouldConsumeEvent: true
            )
        default:
            if isFunction {
                return .fn
            }
            return nil
        }
    }

    /// Creates a shortcut from a regular key or key combination event (`keyDown`).
    static func from(keyCode: UInt16, modifierFlagsRaw: UInt, characters: String?) -> PushToTalkShortcut {
        let relevantFlags = UInt64(modifierFlagsRaw) & relevantModifierMask

        var parts: [String] = []
        if relevantFlags & CGEventFlags.maskControl.rawValue != 0 { parts.append("⌃") }
        if relevantFlags & CGEventFlags.maskAlternate.rawValue != 0 { parts.append("⌥") }
        if relevantFlags & CGEventFlags.maskShift.rawValue != 0 { parts.append("⇧") }
        if relevantFlags & CGEventFlags.maskCommand.rawValue != 0 { parts.append("⌘") }

        let keyName = keyDisplayName(for: keyCode, characters: characters)
        parts.append(keyName)

        let displayName = parts.joined(separator: " ")

        return PushToTalkShortcut(
            kind: .keyCombo,
            keyCode: Int64(keyCode),
            modifierFlags: relevantFlags,
            deviceMask: 0,
            displayName: displayName,
            shouldConsumeEvent: true
        )
    }

    // MARK: - Key Display Name Formatter

    static func keyDisplayName(for keyCode: UInt16, characters: String?) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Forward Delete"
        case kVK_Escape: return "Esc"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 116: return "Page Up"
        case 121: return "Page Down"
        case 115: return "Home"
        case 119: return "End"
        default:
            if let chars = characters?.uppercased(), !chars.isEmpty {
                return chars
            }
            return "Key(\(keyCode))"
        }
    }
}
