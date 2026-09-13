# HamsFlow

A high-performance, 100% on-device neural voice dictation application built for macOS, implementing Apple Neural Engine CoreML acceleration and Apple HIG minimalist design principles.

## Overview

HamsFlow provides real-time, private, zero-latency speech-to-text dictation across all macOS applications. The interface is crafted around a minimal, distraction-free aesthetic inspired by shadcn/ui and modern Apple design, featuring an ultra-compact floating status pill, dynamic monochrome audio waveforms, and instant text injection via macOS Accessibility without clobbering the clipboard.

## Core Features

- **Zero-Latency Neural Transcription**: Streams tokens in real time directly from Apple's native `SpeechAnalyzer` (macOS 26 / 15 Sequoia) and offline CoreML Parakeet TDT on Apple Silicon.
- **Hybrid Trigger Paradigm**: Supports both Push-to-Talk (press & hold >350ms, release to transcribe) and Toggle Mode (quick tap <350ms to start continuous listening, tap again to finish).
- **Intelligent Text Formatting**: Automatically strips filler vocalizations ("um", "uh", "like"), fixes punctuation, capitalizes sentences, and cleans spacing.
- **Custom Vocabulary Biasing**: Custom dictionary replacement engine guaranteeing correct phonetic substitution for technical acronyms, names, and proprietary terms.
- **Universal Text Injection**: Injects transcribed text directly into any focused application (VSCode, Cursor, Slack, Notes, Chrome, Terminal) via Accessibility CGEvents.
- **100% Air-Gapped Privacy**: Zero audio or telemetry data leaves the host Mac. Fully HIPAA and GDPR compliant.

## Technical Specifications

- **Platform**: macOS 14.0+ (Optimized for macOS 26 / 15 Sequoia)
- **Language**: Swift 6 (Strict Concurrency Checking)
- **Frameworks**: SwiftUI, Speech, AVFoundation, Carbon, CoreGraphics, ApplicationServices
- **Speech Engines**:
  - Apple `SpeechAnalyzer` / `SpeechTranscriber` (Streaming, native)
  - Parakeet TDT via FluidAudio (Offline CoreML on Apple Silicon Neural Engine)
- **Event Monitoring**: Low-level `CGEventTap` supporting dedicated modifiers (Right ⌥, Left ⌥, Right ⌘, fn, Right ⌃) and key combinations (⌥ Space, ⌃ Space).

---

The source code for HamsFlow is private. This repository serves as a portfolio showcase of the application's interface design, product architecture, and technical capabilities.
