import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class CompanionVoice {
  const CompanionVoice(this.name, this.locale, this.isVerified);
  final String name;
  final String locale;

  /// Android TTS has no standard gender field. Name matching is only a hint.
  final bool isVerified;
}

abstract interface class VoicePort {
  set onNotificationStop(void Function()? callback);
  Future<void> initialize();
  Future<String> selectVoice(String partner);
  Future<void> startVisibleSession();
  Future<void> speak(String text, {double rate});
  Future<String?> listen();
  Future<void> stop();
}

class VoiceService implements VoicePort {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  static const _session = MethodChannel('talkmile/session');
  Completer<String?>? _turn;
  String _partial = '';
  bool _ready = false;
  bool _stopped = false;
  @override
  void Function()? onNotificationStop;

  VoiceService() {
    _session.setMethodCallHandler((call) async {
      if (call.method == 'notificationStop') onNotificationStop?.call();
    });
  }

  @override
  Future<void> initialize() async {
    if (_ready) return;
    _ready = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _finishTurn(_partial.trim().isEmpty ? null : _partial.trim());
        }
      },
      onError: (_) =>
          _finishTurn(_partial.trim().isEmpty ? null : _partial.trim()),
    );
    if (!_ready) {
      throw StateError(
        'Speech recognition is unavailable or microphone permission was denied.',
      );
    }
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-IN');
  }

  @override
  Future<void> startVisibleSession() async {
    _stopped = false;
    await _session.invokeMethod<void>('start');
  }

  Future<List<CompanionVoice>> availableVoices() async {
    await initialize();
    final raw = await _tts.getVoices;
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map(
          (voice) => CompanionVoice(
            '${voice['name'] ?? ''}',
            '${voice['locale'] ?? ''}',
            false,
          ),
        )
        .where(
          (voice) => voice.locale.toLowerCase().replaceAll('_', '-') == 'en-in',
        )
        .toList();
  }

  @override
  Future<String> selectVoice(String partner) async {
    final voices = await availableVoices();
    if (voices.isEmpty) {
      await _tts.setLanguage('en-IN');
      return 'No installed Indian English voice was found. Your device will use its available English fallback.';
    }
    // Voice names are vendor-specific; this is a best-effort selection only.
    final marker = partner == 'male'
        ? RegExp(r'\b(male|man)\b', caseSensitive: false)
        : RegExp(r'\b(female|woman)\b', caseSensitive: false);
    final matches = voices.where((v) => marker.hasMatch(v.name)).toList();
    final selected = matches.isNotEmpty ? matches.first : voices.first;
    await _tts.setVoice({'name': selected.name, 'locale': selected.locale});
    return matches.isEmpty
        ? 'This device does not identify a ${partner == 'male' ? 'male' : 'female'} Indian English voice. Using ${selected.name}.'
        : 'Using ${selected.name}. Voice gender and accent depend on the installed TTS engine.';
  }

  @override
  Future<void> speak(String text, {double rate = .48}) async {
    if (_stopped) return;
    await _speech.stop();
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  @override
  Future<String?> listen() async {
    if (_stopped) return null;
    if (_turn != null) throw StateError('A listening turn is already active.');
    _partial = '';
    final turn = Completer<String?>();
    _turn = turn;
    try {
      await _speech.listen(
        onResult: (result) {
          _partial = result.recognizedWords;
          if (result.finalResult) {
            _finishTurn(_partial.trim().isEmpty ? null : _partial.trim());
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: 'en_IN',
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: false,
        ),
      );
      return await turn.future.timeout(
        const Duration(seconds: 32),
        onTimeout: () => null,
      );
    } finally {
      if (identical(_turn, turn)) _turn = null;
      await _speech.stop();
    }
  }

  void _finishTurn(String? words) {
    final turn = _turn;
    if (turn != null && !turn.isCompleted) turn.complete(words);
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _finishTurn(null);
    await _speech.cancel();
    await _tts.stop();
    await _session.invokeMethod<void>('stop');
  }

  Future<void> cancelGuide() async {
    _finishTurn(null);
    await _speech.cancel();
    await _tts.stop();
  }

  Future<void> preview(String partner) async {
    await initialize();
    await selectVoice(partner);
    await _tts.speak(
      partner == 'male'
          ? 'Hello, I am here to practise English with you.'
          : 'Hello, let us make every conversation count.',
    );
  }
}
