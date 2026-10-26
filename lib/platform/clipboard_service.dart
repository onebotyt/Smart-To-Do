import 'dart:async';
import 'package:flutter/services.dart';

abstract class ClipboardService {
  Stream<String> get onLocalCopy;
  Future<void> writeText(String text);
  Future<String?> readText();
  void startListening({Duration pollInterval = const Duration(seconds: 1)});
  void stopListening();
  void dispose();
}

class PlatformClipboardService implements ClipboardService {
  final StreamController<String> _copyController =
      StreamController<String>.broadcast();
  Timer? _pollTimer;
  String? _lastSeenText;
  bool _isListening = false;

  @override
  Stream<String> get onLocalCopy => _copyController.stream;

  @override
  Future<String?> readText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeText(String text) async {
    // Suppress local copy event for incoming remote text
    _lastSeenText = text;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}
  }

  @override
  void startListening({Duration pollInterval = const Duration(seconds: 1)}) {
    if (_isListening) return;
    _isListening = true;

    // Initial seed without emitting
    readText().then((txt) {
      _lastSeenText = txt;
    });

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) async {
      final current = await readText();
      if (current != null && current.isNotEmpty && current != _lastSeenText) {
        _lastSeenText = current;
        _copyController.add(current);
      }
    });
  }

  @override
  void stopListening() {
    _isListening = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    stopListening();
    _copyController.close();
  }
}
