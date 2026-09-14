import MurmurDictionary
import AVFoundation
import Foundation
import Speech

/// Streaming on-device transcription via macOS 26's `SpeechAnalyzer` / `SpeechTranscriber`.
///
/// No model ships with the app — the OS downloads and manages the assets, so the first
/// run for a given locale may block briefly while `AssetInstallationRequest` completes.
actor AppleSpeechEngine: TranscriptionEngine {
    private let locale: Locale

    private var isArabic: Bool {
        locale.identifier.starts(with: "ar") || (locale.language.languageCode?.identifier ?? "") == "ar"
    }

    // Modern SpeechAnalyzer (macOS 15/26) for English and locales supported by SpeechTranscriber
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    // On-device SFSpeechRecognizer for Arabic (ar-SA)
    private var sfRecognizer: SFSpeechRecognizer?
    private var sfRequest: SFSpeechAudioBufferRecognitionRequest?
    private var sfTask: SFSpeechRecognitionTask?

    /// Text the engine has committed. Volatile results are appended on top for display
    /// but discarded as soon as a final result covering the same range arrives.
    private var finalizedText = ""
    private var chunkContinuation: AsyncThrowingStream<TranscriptionChunk, Error>.Continuation?

    init(locale: Locale = Locale.current) {
        self.locale = locale
    }

    func preferredInputFormat() async -> AVAudioFormat? {
        if isArabic {
            return AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)
        }
        let resolvedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
            ?? Locale(identifier: "en-US")
        let module = transcriber ?? Self.makeTranscriber(locale: resolvedLocale)
        if let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) {
            return format
        }
        // Fallback to standard 16kHz mono 16-bit PCM required by SpeechAnalyzer
        return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)
    }

    func start() async throws -> AsyncThrowingStream<TranscriptionChunk, Error> {
        finalizedText = ""
        let (chunks, chunkContinuation) = AsyncThrowingStream<TranscriptionChunk, Error>.makeStream()
        self.chunkContinuation = chunkContinuation

        if isArabic {
            return try startArabic(chunkContinuation: chunkContinuation, chunks: chunks)
        } else {
            return try await startModern(chunkContinuation: chunkContinuation, chunks: chunks)
        }
    }

    private func startArabic(
        chunkContinuation: AsyncThrowingStream<TranscriptionChunk, Error>.Continuation,
        chunks: AsyncThrowingStream<TranscriptionChunk, Error>
    ) throws -> AsyncThrowingStream<TranscriptionChunk, Error> {
        let arabicLocale = Locale(identifier: "ar-SA")
        guard let recognizer = SFSpeechRecognizer(locale: arabicLocale), recognizer.isAvailable else {
            throw TranscriptionError.localeUnsupported(locale)
        }
        self.sfRecognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = true
        self.sfRequest = request

        self.sfTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let nsErrorCode = (error as NSError?)?.code
            let nsErrorDomain = (error as NSError?)?.domain
            let errDescription = error?.localizedDescription

            Task { [weak self] in
                guard let self else { return }
                if let text {
                    await self.updateArabicText(text, isFinal: isFinal)
                }
                if let errDescription {
                    if nsErrorCode != 216 && nsErrorDomain != "kAFAssistantErrorDomain" {
                        Log.speech.error("Arabic recognition task error: \(errDescription)")
                    }
                    await self.finishArabicContinuation()
                }
            }
        }
        Log.speech.info("Arabic on-device speech recognizer started (on-device: \(recognizer.supportsOnDeviceRecognition))")
        return chunks
    }

    private func updateArabicText(_ text: String, isFinal: Bool) {
        finalizedText = text
        chunkContinuation?.yield(TranscriptionChunk(text: text, isFinal: isFinal))
        if isFinal {
            chunkContinuation?.finish()
            chunkContinuation = nil
        }
    }

    private func finishArabicContinuation() {
        if !finalizedText.isEmpty {
            chunkContinuation?.yield(TranscriptionChunk(text: finalizedText, isFinal: true))
        }
        chunkContinuation?.finish()
        chunkContinuation = nil
    }

    private func startModern(
        chunkContinuation: AsyncThrowingStream<TranscriptionChunk, Error>.Continuation,
        chunks: AsyncThrowingStream<TranscriptionChunk, Error>
    ) async throws -> AsyncThrowingStream<TranscriptionChunk, Error> {
        guard SpeechTranscriber.isAvailable else {
            throw TranscriptionError.localeUnsupported(locale)
        }

        let resolvedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
            ?? Locale(identifier: "en-US")

        let transcriber = Self.makeTranscriber(locale: resolvedLocale)
        self.transcriber = transcriber

        try await Self.ensureModelInstalled(for: transcriber)

        let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = inputContinuation

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        if let context = await Self.context() {
            try? await analyzer.setContext(context)
        }

        // Drain the transcriber's results into our simpler chunk stream.
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { break }
                    let snapshot = await self.absorb(result)
                    chunkContinuation.yield(TranscriptionChunk(text: snapshot, isFinal: false))
                }
                let final = await self?.finalizedText ?? ""
                chunkContinuation.yield(TranscriptionChunk(text: final, isFinal: true))
                chunkContinuation.finish()
            } catch {
                Log.speech.error("results stream failed: \(error.localizedDescription)")
                chunkContinuation.finish(throwing: error)
            }
        }

        try await analyzer.start(inputSequence: inputStream)
        Log.speech.info("SpeechAnalyzer started for \(resolvedLocale.identifier)")

        return chunks
    }

    func feed(_ chunk: AudioChunk) async {
        if isArabic {
            sfRequest?.append(chunk.buffer)
        } else {
            inputContinuation?.yield(AnalyzerInput(buffer: chunk.buffer))
        }
    }

    func finish() async {
        if isArabic {
            sfRequest?.endAudio()
            try? await Task.sleep(for: .milliseconds(350))
            if let continuation = chunkContinuation {
                if !finalizedText.isEmpty {
                    continuation.yield(TranscriptionChunk(text: finalizedText, isFinal: true))
                }
                continuation.finish()
            }
            chunkContinuation = nil
            sfTask?.cancel()
            sfTask = nil
            sfRequest = nil
            sfRecognizer = nil
        } else {
            inputContinuation?.finish()
            inputContinuation = nil

            do {
                try await analyzer?.finalizeAndFinishThroughEndOfInput()
            } catch {
                Log.speech.error("finalize failed: \(error.localizedDescription)")
                await analyzer?.cancelAndFinishNow()
            }

            chunkContinuation?.finish()
            chunkContinuation = nil
            resultsTask?.cancel()
            resultsTask = nil
            analyzer = nil
            transcriber = nil
        }
    }

    // MARK: - Result accumulation

    /// Folds one result into the running transcript and returns the full text to display.
    ///
    /// Final results are committed; a volatile result is shown appended to the committed
    /// text but never stored, so the next revision replaces it cleanly.
    private func absorb(_ result: SpeechTranscriber.Result) -> String {
        let text = String(result.text.characters)
        guard result.isFinal else {
            return (finalizedText + text).trimmingCharacters(in: .whitespaces)
        }
        finalizedText += text
        return finalizedText.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Setup helpers

    /// The dictionary's words, handed to the analyzer as contextual strings.
    ///
    /// Reads the store on the main actor because that's where it lives; the resulting array
    /// of strings is plain value data and crosses back safely.
    /// - Returns: nil when the dictionary is empty, so an empty context is never set for
    ///   nothing.
    ///
    /// Hops to the main actor rather than asserting it. The store is main-actor isolated and
    /// this runs on the engine's own executor — `MainActor.assumeIsolated` here doesn't check
    /// that claim, it asserts it, and takes the whole process down when it's false.
    private static func context() async -> AnalysisContext? {
        let phrases = await MainActor.run { DictionaryStore.shared.biasPhrases }
        guard !phrases.isEmpty else { return nil }

        let context = AnalysisContext()
        context.contextualStrings[.general] = phrases
        Log.speech.info("biasing with \(phrases.count, privacy: .public) dictionary phrase(s)")
        return context
    }

    private static func makeTranscriber(locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            // `.volatileResults` is what makes live text appear while you're still talking.
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
    }

    private static func ensureModelInstalled(for transcriber: SpeechTranscriber) async throws {
        let status = await AssetInventory.status(forModules: [transcriber])
        if status != .installed {
            Log.speech.info("Speech model asset status: \(String(describing: status)), requesting installation...")
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
                Log.speech.info("Speech model assets successfully installed")
            }
        }
    }
}
