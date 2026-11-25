import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talkmile/core/audio/voice_service.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/network/ai_gateway.dart';
import 'package:talkmile/features/conversation/domain/conversation_models.dart';
import 'package:talkmile/features/conversation/domain/voice_command.dart';
import 'package:talkmile/features/home/domain/practice_catalog.dart';

class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit({
    required this.voice,
    required this.gateway,
    required this.store,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const ConversationState()) {
    voice.onNotificationStop = stop;
    unawaited(_restorePersistedSession());
  }
  final VoicePort voice;
  final AiGatewayPort gateway;
  final LocalStore store;
  final DateTime Function() _now;
  final List<Map<String, String>> _recent = [];
  final List<LearnerCorrection> _correctionHistory = [];
  CancelToken? _request;
  Future<void>? _stopping;
  Timer? _timer;
  DateTime? _startedAt;
  int _generation = 0;
  String _lastSpeech = '';
  String _lastCorrection = '';
  String _storyState = '';
  int _chapters = 0;
  DateTime? _nextCorrectionReview;
  bool _weeklyVocabularyReview = false;

  bool get active => switch (state.phase) {
    SessionPhase.idle || SessionPhase.stopped || SessionPhase.error => false,
    _ => true,
  };

  Future<bool> start({String? topic}) async {
    return _beginSession(topic: topic, resumeUtterance: null, restoring: false);
  }

  Future<void> _restorePersistedSession() async {
    final saved = await _tryLocalRead(() async => store.sessionResume);
    if (saved == null || isClosed || active) return;
    await _beginSession(
      topic: saved.topic == 'Open conversation' ? null : saved.topic,
      resumeUtterance: saved.utterance,
      restoring: true,
    );
  }

  Future<bool> _beginSession({
    required String? topic,
    required String? resumeUtterance,
    required bool restoring,
  }) async {
    if (active) return false;
    if (store.gatewayUrl.isEmpty) {
      emit(
        state.copyWith(
          phase: SessionPhase.error,
          status: 'The TalkMile AI service is unavailable.',
        ),
      );
      return false;
    }
    final generation = ++_generation;
    _chapters = 0;
    _recent.clear();
    _correctionHistory.clear();
    _lastCorrection = '';
    _lastSpeech = '';
    emit(
      ConversationState(
        phase: SessionPhase.initializing,
        topic: topic ?? 'Open conversation',
        status: 'Preparing microphone',
      ),
    );
    try {
      await voice.initialize();
      if (generation != _generation) return false;
      final notice = await voice.selectVoice(
        personaFor(store.companion).gender,
      );
      if (generation != _generation) return false;
      final backgroundNotice = await voice.startVisibleSession(
        promptForBatteryExemption: !restoring,
      );
      if (generation != _generation) {
        await voice.stop();
        return false;
      }
      _startedAt = _now();
      await _tryLocalWrite(
        () => store.saveSessionResume(
          topic: topic ?? 'Open conversation',
          utterance: resumeUtterance ?? _initialUtterance(topic),
        ),
      );
      _nextCorrectionReview = _startedAt!.add(const Duration(minutes: 5));
      _weeklyVocabularyReview =
          await _tryLocalRead(store.shouldReviewWeeklyVocabulary) ?? false;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isClosed && _startedAt != null) {
          emit(state.copyWith(elapsed: DateTime.now().difference(_startedAt!)));
        }
      });
      emit(
        state.copyWith(
          voiceNotice: [
            notice,
            backgroundNotice,
          ].whereType<String>().where((text) => text.isNotEmpty).join(' '),
        ),
      );
      unawaited(
        _run(generation, topic: topic, resumeUtterance: resumeUtterance),
      );
      return true;
    } catch (error) {
      try {
        await voice.stop().timeout(const Duration(seconds: 5));
      } catch (_) {}
      emit(state.copyWith(phase: SessionPhase.error, status: _message(error)));
      return false;
    }
  }

  Future<void> _run(
    int generation, {
    String? topic,
    String? resumeUtterance,
  }) async {
    var utterance = resumeUtterance ?? '';
    try {
      if (resumeUtterance == null || topic == 'Continue previous story') {
        final saved = await _tryLocalRead(store.readStory);
        _storyState = topic == 'Continue previous story'
            ? (saved?['storyState'] as String? ?? '')
            : '';
      }
      utterance = resumeUtterance ?? _initialUtterance(topic);
      while (generation == _generation && !isClosed) {
        await _tryLocalWrite(
          () => store.saveSessionResume(
            topic: topic ?? 'Open conversation',
            utterance: utterance,
          ),
        );
        emit(
          state.copyWith(
            phase: SessionPhase.processing,
            status: 'Thinking about your answer',
          ),
        );
        final correctionReviewDue =
            _nextCorrectionReview != null &&
            !_now().isBefore(_nextCorrectionReview!);
        final correctionReview =
            correctionReviewDue && _correctionHistory.isNotEmpty;
        final persona = personaFor(store.companion);
        final reviewWords = _weeklyVocabularyReview
            ? await _tryLocalRead(store.weeklyVocabularyWords) ??
                  const <String>[]
            : const <String>[];
        CoachResponse? reply;
        var retries = 0;
        while (reply == null && generation == _generation && !isClosed) {
          _request = CancelToken();
          try {
            reply = await gateway.reply(
              store: store,
              utterance: utterance,
              mode:
                  topic == 'Continue previous story' ||
                      topic?.startsWith('Story:') == true
                  ? 'story'
                  : store.mode,
              difficulty: store.difficulty,
              corrections: store.correctionFrequency,
              storyState: _storyState,
              persona:
                  '${persona.name}, age ${persona.age}, ${persona.gender}, your ${persona.role}; ${persona.style}.',
              correctionReview: correctionReview,
              correctionHistory: correctionReview
                  ? _correctionHistory.map((item) => item.toJson()).toList()
                  : const [],
              reviewWords: reviewWords,
              recentTurns: _recent,
              cancelToken: _request!,
            );
          } on DioException catch (error) {
            if (CancelToken.isCancel(error) || generation != _generation) {
              rethrow;
            }
            retries++;
            await _waitToRetry(
              generation,
              retries,
              isQuota: error.response?.statusCode == 429,
            );
          } catch (error) {
            if (generation != _generation) break;
            retries++;
            await _waitToRetry(
              generation,
              retries,
              isQuota:
                  error is AiQuotaException ||
                  error.toString().toLowerCase().contains('quota'),
              quotaMessage: error is AiQuotaException ? error.message : null,
            );
          } finally {
            _request = null;
          }
        }
        if (reply == null || generation != _generation) break;
        final completedReply = reply;
        if (correctionReviewDue) {
          _nextCorrectionReview = _now().add(const Duration(minutes: 5));
        }
        if (correctionReview) _correctionHistory.clear();
        _correctionHistory.addAll(completedReply.corrections);
        if (_correctionHistory.length > 16) {
          _correctionHistory.removeRange(0, _correctionHistory.length - 16);
        }
        if (_weeklyVocabularyReview) {
          await _tryLocalWrite(store.markWeeklyVocabularyReview);
          _weeklyVocabularyReview = false;
        }
        _storyState = completedReply.storyState;
        _lastCorrection = completedReply.correction ?? '';
        _lastSpeech = completedReply.speech;
        if (completedReply.chapterCompleted) _chapters++;
        await _tryLocalWrite(
          () => store.saveStory({
            'storyState': _storyState,
            'topic': state.topic,
          }),
        );
        await _tryLocalWrite(
          () => store.recordInsights(
            completedReply.vocabulary,
            completedReply.correction,
          ),
        );
        for (final correction in completedReply.corrections.skip(1)) {
          await _tryLocalWrite(
            () => store.recordInsights(const [], correction.improved),
          );
        }
        _remember(utterance, _lastSpeech);
        emit(
          state.copyWith(
            phase: SessionPhase.speaking,
            status: 'Your companion is speaking',
            spokenText: _lastSpeech,
          ),
        );
        await _speakUntilAvailable(_lastSpeech);
        if (generation != _generation) break;
        var microphoneFailures = 0;
        while (generation == _generation) {
          emit(
            state.copyWith(
              phase: SessionPhase.listening,
              status: 'Listening to you',
            ),
          );
          String? heard;
          try {
            heard = await voice.listen();
          } catch (_) {
            if (generation != _generation) break;
            microphoneFailures++;
            final delay = Duration(
              seconds: [2, 4, 8, 16, 30][(microphoneFailures - 1).clamp(0, 4)],
            );
            emit(
              state.copyWith(
                phase: SessionPhase.recovering,
                status: 'Reconnecting to the microphone in ${delay.inSeconds}s',
              ),
            );
            try {
              await voice.recover().timeout(const Duration(seconds: 10));
            } catch (_) {}
            await Future<void>.delayed(delay);
            continue;
          }
          if (generation != _generation) break;
          microphoneFailures = 0;
          if (heard == null || heard.isEmpty) {
            emit(
              state.copyWith(
                phase: SessionPhase.listening,
                status: 'Still listening. Speak when you are ready.',
              ),
            );
            continue;
          }
          final command = interpretVoiceCommand(heard);
          if (command != null) {
            final instruction = await _handleCommand(command);
            if (instruction.isEmpty) continue;
            utterance = instruction;
          } else {
            utterance = heard;
          }
          await _tryLocalWrite(
            () => store.saveSessionResume(
              topic: topic ?? 'Open conversation',
              utterance: utterance,
            ),
          );
          break;
        }
        if (generation != _generation) break;
        emit(state.copyWith(turns: state.turns + 1));
      }
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error) && generation == _generation) {
        await _resumeAfterFailure(generation, topic, utterance);
      }
    } catch (_) {
      if (generation == _generation) {
        await _resumeAfterFailure(generation, topic, utterance);
      }
    }
  }

  String _initialUtterance(String? topic) => topic == null
      ? 'Start a friendly speaking practice. Introduce an interesting everyday topic.'
      : topic == 'Continue previous story' && _storyState.isNotEmpty
      ? 'Continue the saved interactive story and ask what I do next.'
      : 'Start a speaking practice about $topic.';

  Future<void> _resumeAfterFailure(
    int generation,
    String? topic,
    String utterance,
  ) async {
    emit(
      state.copyWith(
        phase: SessionPhase.recovering,
        status:
            'Recovering the conversation. It will stay active until you end it.',
      ),
    );
    try {
      await voice.recover().timeout(const Duration(seconds: 10));
    } catch (_) {}
    await Future<void>.delayed(const Duration(seconds: 3));
    if (generation == _generation && !isClosed) {
      unawaited(_run(generation, topic: topic, resumeUtterance: utterance));
    }
  }

  Future<void> _waitToRetry(
    int generation,
    int failures, {
    bool isQuota = false,
    String? quotaMessage,
  }) async {
    final delay = isQuota
        ? const Duration(minutes: 1)
        : Duration(seconds: [2, 4, 8, 16, 30][(failures - 1).clamp(0, 4)]);
    emit(
      state.copyWith(
        phase: SessionPhase.temporarilyPaused,
        status: isQuota
            ? '${quotaMessage ?? 'AI limit reached.'} Retrying in 60s.'
            : 'Connection interrupted. Retrying in ${delay.inSeconds}s.',
      ),
    );
    await Future<void>.delayed(delay);
    if (generation != _generation || isClosed) return;
  }

  Future<void> _speakUntilAvailable(String text) async {
    var failures = 0;
    while (active && !isClosed) {
      try {
        await voice.speak(text, rate: store.speechRate);
        return;
      } catch (_) {
        failures++;
        emit(
          state.copyWith(
            phase: SessionPhase.recovering,
            status: 'Reconnecting to your speaking partner',
          ),
        );
        try {
          await voice.recoverSpeech().timeout(const Duration(seconds: 10));
        } catch (_) {}
        await Future<void>.delayed(
          Duration(seconds: [2, 4, 8, 16, 30][(failures - 1).clamp(0, 4)]),
        );
      }
    }
  }

  Future<String> _handleCommand(VoiceCommand command) async {
    switch (command) {
      case VoiceCommand.repeat:
        await _speakUntilAvailable(_lastSpeech);
        return '';
      case VoiceCommand.slower:
        await store.setSpeechRate((store.speechRate - .08).clamp(.4, .75));
        await _speakUntilAvailable('I will speak more slowly.');
        return '';
      case VoiceCommand.male:
      case VoiceCommand.female:
        final partner = command == VoiceCommand.male ? 'male' : 'female';
        await store.setCompanion(partner);
        final notice = await voice.selectVoice(partner);
        emit(state.copyWith(voiceNotice: notice));
        await _speakUntilAvailable('Voice preference updated.');
        return '';
      case VoiceCommand.harder:
        await store.setDifficulty('advanced');
        return 'Please make the next question more challenging.';
      case VoiceCommand.easier:
        await store.setDifficulty('beginner');
        return 'Please make the next question easier.';
      case VoiceCommand.mistake:
        await _speakUntilAvailable(
          _lastCorrection.isEmpty
              ? 'I have not noticed a significant correction yet.'
              : 'You could say: $_lastCorrection',
        );
        return '';
      case VoiceCommand.hint:
        return 'Please give me a short hint for the current question.';
      case VoiceCommand.simpler:
        return 'Please explain the current question in simpler English.';
      case VoiceCommand.changeTopic:
        return 'Change to an interesting everyday topic.';
      case VoiceCommand.continueStory:
        return 'Continue our interactive story.';
      case VoiceCommand.anotherQuestion:
        return 'Ask me another question on this topic.';
    }
  }

  void _remember(String user, String assistant) {
    _recent.add({'user': user, 'assistant': assistant});
    if (_recent.length > 8) _recent.removeAt(0);
  }

  Future<void> stop() {
    final inProgress = _stopping;
    if (inProgress != null) return inProgress;
    final task = _stopOnce();
    _stopping = task;
    return task.whenComplete(() => _stopping = null);
  }

  Future<void> _stopOnce() async {
    if (state.phase == SessionPhase.stopped ||
        state.phase == SessionPhase.idle) {
      return;
    }
    ++_generation;
    _request?.cancel('Session stopped');
    _timer?.cancel();
    try {
      await voice.stop().timeout(const Duration(seconds: 5));
    } catch (_) {}
    final duration = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    if (duration.inSeconds > 0) {
      await _tryLocalWrite(
        () => store.addPractice(duration, state.turns, chapters: _chapters),
      );
    }
    await _tryLocalWrite(store.clearSessionResume);
    _startedAt = null;
    emit(
      state.copyWith(
        phase: SessionPhase.stopped,
        status: 'Session ended',
        elapsed: duration,
      ),
    );
  }

  String _message(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('FormatException: ', '');

  Future<T?> _tryLocalRead<T>(Future<T> Function() read) async {
    try {
      return await read().timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  Future<void> _tryLocalWrite(Future<void> Function() write) async {
    try {
      await write().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Local progress failures must not end a live speaking session.
    }
  }

  @override
  Future<void> close() async {
    await stop();
    _timer?.cancel();
    return super.close();
  }
}
