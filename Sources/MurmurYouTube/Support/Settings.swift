import Foundation
import Observation

/// Which language is used for on-device dictation.
enum DictationLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en-US"
    case arabic = "ar-SA"
    case auto = "auto"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English (US)"
        case .arabic: return "العربية (Arabic)"
        case .auto: return "Auto (System Locale)"
        }
    }

    var shortName: String {
        switch self {
        case .english: return "English"
        case .arabic: return "العربية"
        case .auto: return "Auto"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .arabic: return "🇸🇦"
        case .auto: return "🌐"
        }
    }

    var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en-US")
        case .arabic:
            return Locale(identifier: "ar-SA")
        case .auto:
            return Locale.current
        }
    }
}

/// Which speech engine transcribes an utterance.
enum SpeechEngineChoice: String, CaseIterable, Sendable {
    case apple
    case parakeet

    var displayName: String {
        switch self {
        case .apple: "Apple (streaming)"
        case .parakeet: "Parakeet (batch)"
        }
    }

    /// Apple shows text while you talk; Parakeet only resolves on release.
    var showsLiveText: Bool { self == .apple }
}

@MainActor
@Observable
final class Settings {
    static let shared = Settings()

    var language: DictationLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }

    var pushToTalkShortcut: PushToTalkShortcut {
        didSet {
            if let data = try? JSONEncoder().encode(pushToTalkShortcut) {
                defaults.set(data, forKey: Keys.pushToTalkShortcut)
            }
            defaults.set(pushToTalkShortcut.displayName, forKey: Keys.pushToTalkKey)
        }
    }

    /// Kept for backward compatibility.
    var pushToTalkKey: PushToTalkKey {
        get {
            switch pushToTalkShortcut {
            case .rightOption: return .rightOption
            case .fn: return .fn
            case .rightCommand: return .rightCommand
            default: return .rightOption
            }
        }
        set {
            pushToTalkShortcut = newValue.shortcut
        }
    }

    var engine: SpeechEngineChoice {
        didSet { defaults.set(engine.rawValue, forKey: Keys.engine) }
    }

    /// Run every engine on each recording and show them side by side, instead of
    /// transcribing with one. Nothing is typed into the focused app in this mode.
    var compareMode: Bool {
        didSet { defaults.set(compareMode, forKey: Keys.compareMode) }
    }

    /// Run the cleanup pass before injecting. Off = raw engine output.
    var cleanupEnabled: Bool {
        didSet { defaults.set(cleanupEnabled, forKey: Keys.cleanupEnabled) }
    }

    /// Use the on-device LLM for cleanup instead of the deterministic rule pass.
    var smartCleanup: Bool {
        didSet { defaults.set(smartCleanup, forKey: Keys.smartCleanup) }
    }

    /// Play a short tick when capture starts and stops.
    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let language = "dictationLanguage"
        static let pushToTalkShortcut = "pushToTalkShortcut"
        static let pushToTalkKey = "pushToTalkKey"
        static let cleanupEnabled = "cleanupEnabled"
        static let soundEnabled = "soundEnabled"
        static let engine = "engine"
        static let smartCleanup = "smartCleanup"
        static let compareMode = "compareMode"
    }

    private init() {
        if let raw = defaults.string(forKey: Keys.language),
           let savedLang = DictationLanguage(rawValue: raw) {
            language = savedLang
        } else {
            let preferred = Locale.preferredLanguages.first ?? ""
            language = preferred.starts(with: "ar") ? .arabic : .english
        }

        if let data = defaults.data(forKey: Keys.pushToTalkShortcut),
           let savedShortcut = try? JSONDecoder().decode(PushToTalkShortcut.self, from: data) {
            pushToTalkShortcut = savedShortcut
        } else if let raw = defaults.string(forKey: Keys.pushToTalkKey),
                  let legacyKey = PushToTalkKey(rawValue: raw) {
            pushToTalkShortcut = legacyKey.shortcut
        } else {
            pushToTalkShortcut = .rightOption
        }

        // Apple by default: no download, no dependency, live text while speaking.
        engine = SpeechEngineChoice(rawValue: defaults.string(forKey: Keys.engine) ?? "") ?? .apple
        cleanupEnabled = defaults.object(forKey: Keys.cleanupEnabled) as? Bool ?? true
        smartCleanup = defaults.object(forKey: Keys.smartCleanup) as? Bool ?? false
        compareMode = defaults.object(forKey: Keys.compareMode) as? Bool ?? false
        soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
    }
}
