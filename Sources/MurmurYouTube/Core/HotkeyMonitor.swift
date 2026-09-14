import AppKit
import Carbon.HIToolbox
import Foundation

/// Which modifier key holds the mic open (legacy enum kept for presets/compatibility).
enum PushToTalkKey: String, CaseIterable, Sendable {
    case rightOption
    case fn
    case rightCommand

    var shortcut: PushToTalkShortcut {
        switch self {
        case .rightOption: .rightOption
        case .fn: .fn
        case .rightCommand: .rightCommand
        }
    }

    var keyCode: Int64 { shortcut.keyCode }
    var flag: CGEventFlags { CGEventFlags(rawValue: shortcut.deviceMask) }
    var displayName: String { shortcut.displayName }
    var shouldConsumeEvent: Bool { shortcut.shouldConsumeEvent }
}

/// Watches for a held hotkey (single modifier or key combo) using a `CGEventTap`.
///
/// A tap is required rather than `NSEvent.addGlobalMonitor` because `fn` and left/right
/// modifier discrimination don't surface through the higher-level APIs, and global monitors
/// cannot swallow events. This needs Accessibility permission; without it `CGEvent.tapCreate`
/// returns nil.
@MainActor
final class HotkeyMonitor {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isPressed = false

    var shortcut: PushToTalkShortcut = .rightOption

    /// Backward compatibility bridge for `PushToTalkKey`.
    var key: PushToTalkKey {
        get {
            switch shortcut {
            case .rightOption: .rightOption
            case .fn: .fn
            case .rightCommand: .rightCommand
            default: .rightOption
            }
        }
        set {
            shortcut = newValue.shortcut
        }
    }

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    /// - Returns: `false` if the tap couldn't be created — almost always missing Accessibility permission.
    @discardableResult
    func start() -> Bool {
        stop()

        let mask = (1 << CGEventType.flagsChanged.rawValue) |
                   (1 << CGEventType.keyDown.rawValue) |
                   (1 << CGEventType.keyUp.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

                // CGEvent isn't Sendable, so pull out the plain values before crossing into
                // actor-isolated code. The tap was added to the main run loop, so this
                // callback genuinely does run on the main thread.
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                let consume = MainActor.assumeIsolated {
                    monitor.handle(type: type, keyCode: keyCode, flags: flags, isRepeat: isRepeat)
                }
                return consume ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            Log.hotkey.error("tapCreate failed — Accessibility permission missing?")
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        Log.hotkey.info("listening for \(self.shortcut.displayName)")
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isPressed = false
    }

    // MARK: - Tap callback

    /// - Returns: `true` if the event should be swallowed rather than passed along.
    private func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags, isRepeat: Bool) -> Bool {
        // The system disables a tap that runs too slowly or is interrupted; re-arm it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }

        if shortcut.kind == .modifierOnly {
            guard type == .flagsChanged, keyCode == shortcut.keyCode else { return false }

            let flagMask = CGEventFlags(rawValue: shortcut.deviceMask)
            let nowPressed = flags.contains(flagMask)
            guard nowPressed != isPressed else { return false }
            isPressed = nowPressed

            if nowPressed { onPress?() } else { onRelease?() }

            return shortcut.shouldConsumeEvent
        } else {
            // Key combination or regular key
            let relevantFlags = flags.rawValue & PushToTalkShortcut.relevantModifierMask
            let targetFlags = shortcut.modifierFlags & PushToTalkShortcut.relevantModifierMask

            if type == .keyDown {
                guard keyCode == shortcut.keyCode else { return false }
                guard relevantFlags == targetFlags else { return false }

                if isPressed || isRepeat {
                    return shortcut.shouldConsumeEvent
                }

                isPressed = true
                onPress?()
                return shortcut.shouldConsumeEvent
            } else if type == .keyUp {
                guard keyCode == shortcut.keyCode else { return false }
                guard isPressed else { return false }

                isPressed = false
                onRelease?()
                return shortcut.shouldConsumeEvent
            } else if type == .flagsChanged {
                // If user released the modifier before releasing the key, end dictation.
                if isPressed && (relevantFlags != targetFlags) {
                    isPressed = false
                    onRelease?()
                    return false
                }
                return false
            }

            return false
        }
    }
}
