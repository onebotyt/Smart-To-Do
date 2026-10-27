import 'dart:io';
import 'package:flutter/services.dart';

/// Platform-agnostic contract for native voice synthesis and speech input.
abstract class VoiceService {
  Future<void> speak(String text);
  Future<void> stop();
  Future<String?> startListening();
}

/// Native implementation utilizing built-in platform speech engines
/// (Windows SAPI / System.Speech and Android TextToSpeech / RecognizerIntent
/// without requiring heavy 3rd-party dependencies).
class NativeVoiceService implements VoiceService {
  static final NativeVoiceService instance = NativeVoiceService._();
  NativeVoiceService._();

  static const MethodChannel _voiceChannel = MethodChannel('com.synctask/voice');

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
      } else if (Platform.isAndroid) {
        await _voiceChannel.invokeMethod('speak', {'text': sanitized});
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
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (Platform.isAndroid) {
      try {
        await _voiceChannel.invokeMethod('stop');
      } catch (_) {}
    }
  }

  @override
  Future<String?> startListening() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    if (Platform.isAndroid) {
      try {
        final result = await _voiceChannel.invokeMethod<String>('startListening');
        if (result != null && result.trim().isNotEmpty) {
          return result.trim();
        }
      } catch (_) {}
    }
    return null;
  }
}
