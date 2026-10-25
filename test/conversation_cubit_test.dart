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
  Future<void> stop() async {
    stops++;
    if (pending != null && !pending!.isCompleted) pending!.complete(null);
  }
}

class FakeGateway implements AiGatewayPort {
  int calls = 0;
  @override
  Future<CoachResponse> reply({required LocalStore store,
      required String utterance, required String mode,
      required String difficulty, required String corrections,
      required String storyState,
      required List<Map<String, String>> recentTurns,
      required CancelToken cancelToken}) async {
    calls++;
    return const CoachResponse(spokenText: 'Welcome.',
      nextQuestion: 'How was your day?', storyState: '',
      difficulty: 'intermediate');
  }
}

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
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
    final cubit = ConversationCubit(voice: voice, gateway: gateway, store: store);

    expect(await cubit.start(), isTrue);
    await until(() => cubit.state.phase == SessionPhase.listening);
    expect(gateway.calls, 1);
    expect(await cubit.start(), isFalse);

    voice.pending!.complete(null);
    await until(() => voice.spoken.length >= 2 &&
        cubit.state.phase == SessionPhase.listening);
    expect(voice.spoken.last, contains('Take your time'));
    expect(cubit.state.phase, SessionPhase.listening);

    await Future.wait([cubit.stop(), cubit.stop()]);
    expect(cubit.state.phase, SessionPhase.stopped);
    expect(voice.stops, 1);
    await cubit.close();
    await store.close();
  });
}
