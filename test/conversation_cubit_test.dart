import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talkmile/core/audio/voice_service.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/network/ai_gateway.dart';
import 'package:talkmile/features/conversation/domain/conversation_models.dart';
import 'package:talkmile/features/conversation/presentation/conversation_cubit.dart';

class FakeVoice implements VoicePort {
  @override
  void Function()? onNotificationStop;
  final spoken = <String>[];
  Completer<String?>? pending;
  int stops = 0;

  @override
  Future<void> initialize() async {}
  @override
  Future<String> selectVoice(String partner) async => 'Using test voice';
  @override
  Future<String?> startVisibleSession() async => null;
  @override
  Future<void> speak(String text, {double rate = .48}) async {
    spoken.add(text);
  }

  @override
  Future<String?> listen() {
    pending = Completer<String?>();
    return pending!.future;
  }

  @override
  Future<void> recover() async {}

  @override
  Future<void> stop() async {
    stops++;
    if (pending != null && !pending!.isCompleted) pending!.complete(null);
  }
}

class FakeGateway implements AiGatewayPort {
  int calls = 0;
  int failuresRemaining = 0;
  final correctionReviewCalls = <bool>[];
  final correctionHistoryCalls = <List<Map<String, String>>>[];
  final replies = <CoachResponse>[];
  @override
  Future<CoachResponse> reply({
    required LocalStore store,
    required String utterance,
    required String mode,
    required String difficulty,
    required String corrections,
    required String storyState,
    String persona =
        'Mira, a friendly neighbor in her late twenties; warm and relaxed',
    bool correctionReview = false,
    List<Map<String, String>> correctionHistory = const [],
    List<String> reviewWords = const [],
    required List<Map<String, String>> recentTurns,
    required CancelToken cancelToken,
  }) async {
    calls++;
    correctionReviewCalls.add(correctionReview);
    correctionHistoryCalls.add(correctionHistory);
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('Temporary connection failure');
    }
    if (replies.length >= calls) return replies[calls - 1];
    return const CoachResponse(
      spokenText: 'Welcome.',
      nextQuestion: 'How was your day?',
      storyState: '',
      difficulty: 'intermediate',
    );
  }
}

Future<void> until(bool Function() condition, {int attempts = 100}) async {
  for (var i = 0; i < attempts && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'silence does not speak prompts and Stop releases the session',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final store = LocalStore(NativeDatabase.memory());
      await store.open();
      await store.setGatewayUrl('https://example.com/v1/reply');
      await store.setGatewayToken('test-token');
      final voice = FakeVoice();
      final gateway = FakeGateway();
      final cubit = ConversationCubit(
        voice: voice,
        gateway: gateway,
        store: store,
      );

      expect(await cubit.start(), isTrue);
      await until(() => cubit.state.phase == SessionPhase.listening);
      expect(gateway.calls, 1);
      expect(await cubit.start(), isFalse);

      final firstListen = voice.pending!;
      firstListen.complete(null);
      await until(() => voice.pending != firstListen);
      expect(voice.spoken, ['Welcome. How was your day?']);
      expect(cubit.state.phase, SessionPhase.listening);

      await Future.wait([cubit.stop(), cubit.stop()]);
      expect(cubit.state.phase, SessionPhase.stopped);
      expect(voice.stops, 1);
      await cubit.close();
      await store.close();
    },
  );

  test('keeps a session alive through a temporary gateway failure', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final store = LocalStore(NativeDatabase.memory());
    await store.open();
    await store.setGatewayUrl('https://example.com/v1/reply');
    await store.setGatewayToken('test-token');
    final voice = FakeVoice();
    final gateway = FakeGateway()..failuresRemaining = 1;
    final cubit = ConversationCubit(
      voice: voice,
      gateway: gateway,
      store: store,
    );

    expect(await cubit.start(), isTrue);
    await until(
      () => cubit.state.phase == SessionPhase.listening,
      attempts: 600,
    );
    expect(gateway.calls, 2);
    expect(cubit.state.phase, isNot(SessionPhase.error));

    await cubit.stop();
    expect(cubit.state.phase, SessionPhase.stopped);
    await cubit.close();
    await store.close();
  });

  test('reviews every captured correction after five minutes', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final store = LocalStore(NativeDatabase.memory());
    await store.open();
    await store.setGatewayUrl('https://example.com/v1/reply');
    await store.setGatewayToken('test-token');
    final voice = FakeVoice();
    final gateway = FakeGateway()
      ..replies.addAll([
        const CoachResponse(
          spokenText: 'Hello.',
          nextQuestion: 'What did you do yesterday?',
          storyState: '',
          difficulty: 'intermediate',
        ),
        const CoachResponse(
          spokenText: 'Thanks for telling me.',
          nextQuestion: 'What happened after lunch?',
          storyState: '',
          difficulty: 'intermediate',
          corrections: [
            LearnerCorrection(
              original: 'I go yesterday',
              improved: 'I went yesterday',
              explanation: 'Use the past form for a finished time.',
            ),
            LearnerCorrection(
              original: 'I was in market',
              improved: 'I was at the market',
              explanation: 'Use “at the market” for this place.',
            ),
          ],
        ),
        const CoachResponse(
          spokenText: 'Let’s review those two sentences.',
          nextQuestion: 'Which one would you like to practise?',
          storyState: '',
          difficulty: 'intermediate',
        ),
      ]);
    var now = DateTime(2026, 11, 21, 10);
    final cubit = ConversationCubit(
      voice: voice,
      gateway: gateway,
      store: store,
      now: () => now,
    );

    expect(await cubit.start(), isTrue);
    await until(() => cubit.state.phase == SessionPhase.listening);
    voice.pending!.complete('I go yesterday and I was in market.');
    await until(
      () => gateway.calls == 2 && cubit.state.phase == SessionPhase.listening,
    );
    expect(gateway.correctionReviewCalls, [false, false]);

    now = now.add(const Duration(minutes: 5));
    voice.pending!.complete('I finished my work early.');
    await until(
      () => gateway.calls == 3 && cubit.state.phase == SessionPhase.listening,
    );

    expect(gateway.correctionReviewCalls, [false, false, true]);
    expect(gateway.correctionHistoryCalls.last, [
      {
        'original': 'I go yesterday',
        'improved': 'I went yesterday',
        'explanation': 'Use the past form for a finished time.',
      },
      {
        'original': 'I was in market',
        'improved': 'I was at the market',
        'explanation': 'Use “at the market” for this place.',
      },
    ]);

    await cubit.stop();
    await cubit.close();
    await store.close();
  });
}
