import AVFoundation
import AppKit
import ApplicationServices
import Foundation
import Speech

/// HamsFlow requires grants to operate seamlessly on macOS:
/// - **Microphone** — audio capture.
/// - **Speech Recognition** — on-device speech transcription for Arabic and native dictation.
/// - **Accessibility** — for both the `CGEventTap` (hotkey) and the AX text insert.
@MainActor
enum Permissions {
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    static var hasMicrophone: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static var hasSpeechRecognition: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// Shows the system Accessibility prompt if the app isn't yet trusted.
    @discardableResult
    static func promptForAccessibility() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    static func requestSpeechRecognition() async -> Bool {
        enableSystemDictationDefaults()
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default:
            return false
        }
    }

    /// Pre-configures macOS dictation defaults to ensure SFSpeechRecognizer doesn't fail with kLSRErrorDomain 201
    static func enableSystemDictationDefaults() {
        let dictationPrefs = "com.apple.speech.recognition.AppleSpeechRecognition.prefs"
        let assistantPrefs = "com.apple.assistant.support"
        let hitoolboxPrefs = "com.apple.HIToolbox"

        CFPreferencesSetAppValue("DictationIMMasterDictationEnabled" as CFString, kCFBooleanTrue, dictationPrefs as CFString)
        CFPreferencesAppSynchronize(dictationPrefs as CFString)

        CFPreferencesSetAppValue("Assistant Enabled" as CFString, kCFBooleanTrue, assistantPrefs as CFString)
        CFPreferencesAppSynchronize(assistantPrefs as CFString)

        CFPreferencesSetAppValue("AppleDictationAutoEnable" as CFString, 1 as CFNumber, hitoolboxPrefs as CFString)
        CFPreferencesAppSynchronize(hitoolboxPrefs as CFString)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    static func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    static func openSpeechRecognitionSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!
        NSWorkspace.shared.open(url)
    }

    static func openDictationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Dictation")!
        NSWorkspace.shared.open(url)
    }
}

