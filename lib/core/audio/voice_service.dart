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

/// Android's TTS API does not expose voice gender, but some engines include it
/// in voice IDs (for example, `en-us-x-sfg#male_1-local`).
String? companionVoiceGender(CompanionVoice voice) {
  final name = voice.name.toLowerCase();
  if (RegExp(
    r'(?:^|[^a-z])(?:female|woman|feminine)(?:$|[^a-z])',
  ).hasMatch(name)) {
    return 'female';
  }
  if (RegExp(
    r'(?:^|[^a-z])(?:male|man|masculine)(?:$|[^a-z])',
  ).hasMatch(name)) {
    return 'male';
  }
  return null;
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

  final expectedGender = partner == 'male' ? 'male' : 'female';
  int rank(CompanionVoice voice) {
    final locale = voice.locale.toLowerCase().replaceAll('_', '-');
    if (locale == 'en-in') return 0;
    if (locale == 'en-gb') return 1;
    if (locale == 'en-us') return 2;
    return 3;
  }

  english.sort((a, b) {
    int genderRank(CompanionVoice voice) {
      final gender = companionVoiceGender(voice);
      if (gender == expectedGender) return 0;
      if (gender == null) return 1;
      return 2;
    }

    final genderOrder = genderRank(a).compareTo(genderRank(b));
    if (genderOrder != 0) return genderOrder;
    final localeOrder = rank(a).compareTo(rank(b));
    if (localeOrder != 0) return localeOrder;
    return a.name.compareTo(b.name);
  });
  return english.first;
}

abstract interface class VoicePort {
  set onNotificationStop(void Function()? callback);
  Future<void> initialize();
  Future<String> selectVoice(String partner);
  Future<String?> startVisibleSession({bool promptForBatteryExemption = true});
  Future<void> speak(String text, {double rate});
  Future<String?> listen();
  Future<void> recover();
  Future<void> recoverSpeech();
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
  bool _sessionActive = false;
  String? _selectedVoiceName;
  String? _selectedVoiceLocale;
  double _selectedVoicePitch = 1;
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
    // Android/OnePlus can mute the Google TTS engine when TalkMile is in the
    // background if speech uses ordinary media attributes. Treat companion
    // replies as spoken navigation guidance so they remain audible while the
    // screen is off and the conversation foreground service is active.
    await _tts.setAudioAttributesForNavigation();
  }

  @override
  Future<String?> startVisibleSession({
    bool promptForBatteryExemption = true,
  }) async {
    if (!promptForBatteryExemption) {
      final permissions = await permissionStatus();
      if (permissions['microphone'] != true) {
        throw StateError('Allow microphone access to resume your session.');
      }
      if (permissions['notification'] != true) {
        throw StateError('Allow notifications to resume your session.');
      }
    }
    final notificationAllowed = await _session.invokeMethod<bool>(
      'requestNotificationPermission',
    );
    if (notificationAllowed != true) {
      throw StateError(
        'Allow notifications to show the active microphone session.',
      );
    }
    final backgroundAllowed = promptForBatteryExemption
        ? await _session.invokeMethod<bool>('requestBackgroundBatteryAccess')
        : (await permissionStatus())['batteryOptimization'] == true;
    _stopped = false;
    await _session.invokeMethod<void>('start');
    _sessionActive = true;
    return backgroundAllowed == true
        ? null
        : 'For screen-off replies, allow TalkMile unrestricted battery use.';
  }

  Future<Map<String, bool>> permissionStatus() async {
    final raw = await _session.invokeMapMethod<String, bool>(
      'permissionStatus',
    );
    return raw ?? const {'microphone': false, 'notification': false};
  }

  Future<void> openAppSettings() =>
      _session.invokeMethod<void>('openAppSettings');

  Future<bool> requestBackgroundBatteryAccess() async =>
      await _session.invokeMethod<bool>('requestBackgroundBatteryAccess') ==
      true;

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
      _selectedVoiceName = null;
      _selectedVoiceLocale = 'en-IN';
      await _tts.setLanguage('en-IN');
      return 'No installed English voice was reported. Your device will use its default speech voice.';
    }
    _selectedVoiceName = selected.name;
    _selectedVoiceLocale = selected.locale;
    final genderMatch = companionVoiceGender(selected) == partner;
    // If an engine exposes no gender labels, a modestly lower pitch makes its
    // male companion sound less like the engine's default feminine voice.
    _selectedVoicePitch = partner == 'male' && !genderMatch ? .84 : 1;
    await _tts.setVoice({'name': selected.name, 'locale': selected.locale});
    await _tts.setPitch(_selectedVoicePitch);
    final indianEnglish =
        selected.locale.toLowerCase().replaceAll('_', '-') == 'en-in';
    if (!indianEnglish) {
      return 'No Indian English voice is installed. Using ${selected.name} (${selected.locale}).';
    }
    return genderMatch
        ? 'Using ${selected.name}.'
        : 'Using ${selected.name} with a lower pitch; install a male English voice for a closer match.';
  }

  @override
  Future<void> speak(String text, {double rate = .62}) async {
    if (_stopped) return;
    if (_sessionActive) {
      await _session.invokeMethod<void>('speak', {
        'text': text,
        'rate': rate,
        'voiceName': _selectedVoiceName,
        'locale': _selectedVoiceLocale,
        'pitch': _selectedVoicePitch,
      });
      return;
    }
    await _speech.stop();
    await _tts.setPitch(_selectedVoicePitch);
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  @override
  Future<String?> listen() async {
    if (_stopped) return null;
    if (_sessionActive) {
      try {
        return await _session
            .invokeMethod<String>('listen')
            .timeout(const Duration(seconds: 65));
      } on TimeoutException {
        await _session.invokeMethod<void>('recoverRecognizer');
        return null;
      }
    }
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
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 8),
          partialResults: true,
          cancelOnError: false,
        ),
      );
      return await turn.future.timeout(
        const Duration(seconds: 52),
        onTimeout: () => null,
      );
    } finally {
      if (identical(_turn, turn)) _turn = null;
      await _speech.stop();
    }
  }

  @override
  Future<void> recover() async {
    if (_stopped) return;
    if (_sessionActive) {
      await _session.invokeMethod<void>('recoverRecognizer');
      return;
    }
    _finishTurn(null);
    await _speech.cancel();
    _ready = false;
    await initialize();
  }

  @override
  Future<void> recoverSpeech() async {
    if (_stopped) return;
    if (_sessionActive) {
      await _session.invokeMethod<void>('recoverSpeech');
      return;
    }
    await _tts.stop();
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-IN');
    await _tts.setAudioAttributesForNavigation();
    if (_selectedVoiceName != null && _selectedVoiceLocale != null) {
      await _tts.setVoice({
        'name': _selectedVoiceName!,
        'locale': _selectedVoiceLocale!,
      });
    }
    await _tts.setPitch(_selectedVoicePitch);
  }

  void _finishTurn(String? words) {
    final turn = _turn;
    if (turn != null && !turn.isCompleted) turn.complete(words);
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _sessionActive = false;
    _finishTurn(null);
    // Stop the foreground service first so a wedged platform speech plugin
    // cannot delay the user's explicit end-session action.
    try {
      await _session
          .invokeMethod<void>('stop')
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await _speech.cancel().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await _tts.stop().timeout(const Duration(seconds: 2));
    } catch (_) {}
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
