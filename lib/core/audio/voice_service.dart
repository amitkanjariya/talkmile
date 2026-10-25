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

CompanionVoice? chooseCompanionVoice(
  List<CompanionVoice> voices,
  String partner,
) {
  final english = voices.where((voice) {
    final locale = voice.locale.toLowerCase().replaceAll('_', '-');
    return locale == 'en' || locale.startsWith('en-');
  }).toList();
  if (english.isEmpty) return null;

  final marker = partner == 'male'
      ? RegExp(r'\b(male|man)\b', caseSensitive: false)
      : RegExp(r'\b(female|woman)\b', caseSensitive: false);
  int rank(CompanionVoice voice) {
    final locale = voice.locale.toLowerCase().replaceAll('_', '-');
    if (locale == 'en-in') return 0;
    if (locale == 'en-gb') return 1;
    if (locale == 'en-us') return 2;
    return 3;
  }

  english.sort((a, b) {
    final localeOrder = rank(a).compareTo(rank(b));
    if (localeOrder != 0) return localeOrder;
    return (marker.hasMatch(b.name) ? 1 : 0) -
        (marker.hasMatch(a.name) ? 1 : 0);
  });
  return english.first;
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
    final notificationAllowed = await _session.invokeMethod<bool>(
      'requestNotificationPermission',
    );
    if (notificationAllowed != true) {
      throw StateError(
        'Allow notifications to show the active microphone session.',
      );
    }
    _stopped = false;
    await _session.invokeMethod<void>('start');
  }

  Future<Map<String, bool>> permissionStatus() async {
    final raw = await _session.invokeMapMethod<String, bool>(
      'permissionStatus',
    );
    return raw ?? const {'microphone': false, 'notification': false};
  }

  Future<void> openAppSettings() =>
      _session.invokeMethod<void>('openAppSettings');

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
        .where((voice) {
          final locale = voice.locale.toLowerCase().replaceAll('_', '-');
          return locale == 'en' || locale.startsWith('en-');
        })
        .toList();
  }

  @override
  Future<String> selectVoice(String partner) async {
    final voices = await availableVoices();
    final selected = chooseCompanionVoice(voices, partner);
    if (selected == null) {
      await _tts.setLanguage('en-IN');
      return 'No installed English voice was reported. Your device will use its default speech voice.';
    }
    final marker = partner == 'male'
        ? RegExp(r'\b(male|man)\b', caseSensitive: false)
        : RegExp(r'\b(female|woman)\b', caseSensitive: false);
    await _tts.setVoice({'name': selected.name, 'locale': selected.locale});
    final indianEnglish =
        selected.locale.toLowerCase().replaceAll('_', '-') == 'en-in';
    final genderHint = marker.hasMatch(selected.name);
    if (!indianEnglish) {
      return 'No Indian English voice is installed. Using ${selected.name} (${selected.locale}).';
    }
    return genderHint
        ? 'Using ${selected.name}. Voice gender and accent depend on the installed TTS engine.'
        : 'This device does not identify a ${partner == 'male' ? 'male' : 'female'} Indian English voice. Using ${selected.name}.';
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

  Future<String> preview(String partner) async {
    await initialize();
    final notice = await selectVoice(partner);
    await _tts.speak(
      partner == 'male'
          ? 'Hello, I am here to practise English with you.'
          : 'Hello, let us make every conversation count.',
    );
    return notice;
  }
}
