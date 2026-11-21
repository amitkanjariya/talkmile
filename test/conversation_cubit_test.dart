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
  Future<void> startVisibleSession() async {}
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
    List<String> reviewWords = const [],
    required List<Map<String, String>> recentTurns,
    required CancelToken cancelToken,
  }) async {
    calls++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('Temporary connection failure');
    }
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

  test('silence prompts again and Stop releases the session', () async {
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

    voice.pending!.complete(null);
    await until(
      () =>
          voice.spoken.length >= 2 &&
          cubit.state.phase == SessionPhase.listening,
    );
    expect(voice.spoken.last, contains('Take your time'));
    expect(cubit.state.phase, SessionPhase.listening);

    await Future.wait([cubit.stop(), cubit.stop()]);
    expect(cubit.state.phase, SessionPhase.stopped);
    expect(voice.stops, 1);
    await cubit.close();
    await store.close();
  });

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
}
