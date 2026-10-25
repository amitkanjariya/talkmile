import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talkmile/core/audio/voice_service.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/network/ai_gateway.dart';
import 'package:talkmile/features/conversation/domain/conversation_models.dart';
import 'package:talkmile/features/conversation/domain/voice_command.dart';

class ConversationCubit extends Cubit<ConversationState> {
  ConversationCubit({
    required this.voice,
    required this.gateway,
    required this.store,
  }) : super(const ConversationState()) {
    voice.onNotificationStop = stop;
  }
  final VoicePort voice;
  final AiGatewayPort gateway;
  final LocalStore store;
  final List<Map<String, String>> _recent = [];
  CancelToken? _request;
  Future<void>? _stopping;
  Timer? _timer;
  DateTime? _startedAt;
  int _generation = 0;
  String _lastSpeech = '';
  String _lastCorrection = '';
  String _storyState = '';
  int _chapters = 0;

  bool get active => switch (state.phase) {
    SessionPhase.idle || SessionPhase.stopped || SessionPhase.error => false,
    _ => true,
  };

  Future<bool> start({String? topic}) async {
    if (active) return false;
    if (store.gatewayUrl.isEmpty || (await store.getGatewayToken()).isEmpty) {
      emit(
        state.copyWith(
          phase: SessionPhase.error,
          status: 'Set up your private AI gateway in Settings first.',
        ),
      );
      return false;
    }
    final generation = ++_generation;
    _chapters = 0;
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
      final notice = await voice.selectVoice(store.companion);
      if (generation != _generation) return false;
      await voice.startVisibleSession();
      if (generation != _generation) {
        await voice.stop();
        return false;
      }
      _startedAt = DateTime.now();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isClosed && _startedAt != null) {
          emit(state.copyWith(elapsed: DateTime.now().difference(_startedAt!)));
        }
      });
      emit(state.copyWith(voiceNotice: notice));
      unawaited(_run(generation, topic: topic));
      return true;
    } catch (error) {
      await voice.stop();
      emit(state.copyWith(phase: SessionPhase.error, status: _message(error)));
      return false;
    }
  }

  Future<void> _run(int generation, {String? topic}) async {
    try {
      final saved = await store.readStory();
      _storyState = topic == 'Continue previous story'
          ? (saved?['storyState'] as String? ?? '')
          : '';
      var utterance = topic == null
          ? 'Start a friendly speaking practice. Introduce an interesting everyday topic.'
          : topic == 'Continue previous story' && _storyState.isNotEmpty
          ? 'Continue the saved interactive story and ask what I do next.'
          : 'Start a speaking practice about $topic.';
      var silentTurns = 0;
      while (generation == _generation && !isClosed) {
        emit(
          state.copyWith(
            phase: SessionPhase.processing,
            status: 'Thinking about your answer',
          ),
        );
        _request = CancelToken();
        final reply = await gateway.reply(
          store: store,
          utterance: utterance,
          mode: topic == 'Continue previous story' ? 'story' : store.mode,
          difficulty: store.difficulty,
          corrections: store.correctionFrequency,
          storyState: _storyState,
          recentTurns: _recent,
          cancelToken: _request!,
        );
        _request = null;
        if (generation != _generation) break;
        _storyState = reply.storyState;
        _lastCorrection = reply.correction ?? '';
        _lastSpeech = reply.speech;
        if (reply.chapterCompleted) _chapters++;
        await store.saveStory({
          'storyState': _storyState,
          'topic': state.topic,
        });
        await store.recordInsights(reply.vocabulary, reply.correction);
        _remember(utterance, _lastSpeech);
        emit(
          state.copyWith(
            phase: SessionPhase.speaking,
            status: 'Your companion is speaking',
            spokenText: _lastSpeech,
          ),
        );
        await voice.speak(_lastSpeech, rate: store.speechRate);
        if (generation != _generation) break;
        while (generation == _generation) {
          emit(
            state.copyWith(
              phase: SessionPhase.listening,
              status: 'Listening to you',
            ),
          );
          final heard = await voice.listen();
          if (generation != _generation) break;
          if (heard == null || heard.isEmpty) {
            silentTurns++;
            final prompt = silentTurns == 1
                ? 'Take your time. I am listening whenever you are ready.'
                : 'We can pause for a moment. Say anything when you are ready.';
            emit(
              state.copyWith(
                phase: SessionPhase.speaking,
                status: 'Waiting for your answer',
                spokenText: prompt,
              ),
            );
            await voice.speak(prompt, rate: store.speechRate);
            continue;
          }
          silentTurns = 0;
          final command = interpretVoiceCommand(heard);
          if (command != null) {
            final instruction = await _handleCommand(command);
            if (instruction.isEmpty) continue;
            utterance = instruction;
          } else {
            utterance = heard;
          }
          break;
        }
        if (generation != _generation) break;
        emit(state.copyWith(turns: state.turns + 1));
      }
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error) && generation == _generation) {
        await _pauseForError(
          'The AI connection stopped. Open the app to retry.',
        );
      }
    } catch (error) {
      if (generation == _generation) await _pauseForError(_message(error));
    }
  }

  Future<String> _handleCommand(VoiceCommand command) async {
    switch (command) {
      case VoiceCommand.repeat:
        await voice.speak(_lastSpeech, rate: store.speechRate);
        return '';
      case VoiceCommand.slower:
        await store.setSpeechRate((store.speechRate - .08).clamp(.3, .55));
        await voice.speak('I will speak more slowly.', rate: store.speechRate);
        return '';
      case VoiceCommand.male:
      case VoiceCommand.female:
        final partner = command == VoiceCommand.male ? 'male' : 'female';
        await store.setCompanion(partner);
        final notice = await voice.selectVoice(partner);
        emit(state.copyWith(voiceNotice: notice));
        await voice.speak('Voice preference updated.', rate: store.speechRate);
        return '';
      case VoiceCommand.harder:
        await store.setDifficulty('advanced');
        return 'Please make the next question more challenging.';
      case VoiceCommand.easier:
        await store.setDifficulty('beginner');
        return 'Please make the next question easier.';
      case VoiceCommand.mistake:
        await voice.speak(
          _lastCorrection.isEmpty
              ? 'I have not noticed a significant correction yet.'
              : 'You could say: $_lastCorrection',
          rate: store.speechRate,
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

  Future<void> _pauseForError(String message) async {
    _timer?.cancel();
    await voice.stop();
    if (_startedAt != null) {
      await store.addPractice(
        DateTime.now().difference(_startedAt!),
        state.turns,
        chapters: _chapters,
      );
      _startedAt = null;
    }
    emit(state.copyWith(phase: SessionPhase.error, status: message));
  }

  Future<void> stop() {
    final inProgress = _stopping;
    if (inProgress != null) return inProgress;
    final task = _stopOnce();
    _stopping = task;
    return task.whenComplete(() => _stopping = null);
  }

  Future<void> _stopOnce() async {
    if (state.phase == SessionPhase.stopped || state.phase == SessionPhase.idle) {
      return;
    }
    ++_generation;
    _request?.cancel('Session stopped');
    _timer?.cancel();
    await voice.stop();
    final duration = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    if (duration.inSeconds > 0) {
      await store.addPractice(duration, state.turns, chapters: _chapters);
    }
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

  @override
  Future<void> close() async {
    await stop();
    _timer?.cancel();
    return super.close();
  }
}
