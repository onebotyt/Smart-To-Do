import 'dart:io';

/// Platform-agnostic contract for native text-to-speech voice output.
abstract class VoiceService {
  Future<void> speak(String text);
  Future<void> stop();
}

/// Native implementation utilizing built-in platform speech synthesizers
/// (Windows SAPI / System.Speech without requiring heavy 3rd-party dependencies).
class NativeVoiceService implements VoiceService {
  static final NativeVoiceService instance = NativeVoiceService._();
  NativeVoiceService._();

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  @override
  Future<void> speak(String text) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (text.trim().isEmpty) return;

    final sanitized = text.replaceAll("'", " ").replaceAll('"', ' ').replaceAll('\n', ' ').trim();
    if (sanitized.isEmpty) return;

    try {
      _isSpeaking = true;
      if (Platform.isWindows) {
        // Asynchronously invoke Windows SpeechSynthesizer in the background
        Process.run('powershell', [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-Command',
          "& { Add-Type -AssemblyName System.Speech; (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('$sanitized') }",
        ]);
      }
    } catch (_) {
      // Graceful fallback if speech synthesizer is unavailable
    } finally {
      _isSpeaking = false;
    }
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
  }
}
