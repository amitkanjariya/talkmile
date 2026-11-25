import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/network/ai_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalStore store;
  late Dio dio;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    store = LocalStore(NativeDatabase.memory());
    await store.open();
    dio = Dio();
  });
  tearDown(() async {
    dio.close();
    await store.close();
  });

  Future<void> reply() async {
    await AiGateway(dio).reply(
      store: store,
      utterance: 'Hello.',
      mode: 'conversation',
      difficulty: 'intermediate',
      corrections: 'gentle',
      storyState: '',
      recentTurns: [],
      cancelToken: CancelToken(),
    );
  }

  test(
    'shared reply sends no key or access code and keeps conversation context',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.headers['Authorization'], isNull);
            expect(options.headers['X-Gemini-API-Key'], isNull);
            expect(options.data['utterance'], 'Hello.');
            expect(options.data['geminiApiKey'], isNull);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'spokenText': 'Hello.',
                  'nextQuestion': 'How was your day?',
                  'corrections': [],
                  'storyState': '',
                  'chapterCompleted': false,
                  'newVocabulary': [],
                  'difficulty': 'intermediate',
                },
              ),
            );
          },
        ),
      );
      await reply();
    },
  );

  test(
    'vocabulary supports shared access without a Gemini key on the phone',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, endsWith('/v1/vocabulary'));
            expect(options.headers['Authorization'], isNull);
            expect(options.headers['X-Gemini-API-Key'], isNull);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'words': List.generate(
                    10,
                    (i) => {
                      'word': 'word$i',
                      'meaning': 'Meaning',
                      'example': 'Example',
                    },
                  ),
                },
              ),
            );
          },
        ),
      );
      expect(await AiGateway(dio).dailyWords(store), hasLength(10));
    },
  );

  test('daily words reuse the same set for the whole day', () async {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await store.saveDailyWordSet(date, [
      for (var i = 0; i < 10; i++)
        {
          'word': 'saved$i',
          'meaning': 'Saved meaning',
          'example': 'Saved example',
        },
    ]);
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );

    final words = await AiGateway(dio).dailyWords(store);

    expect(requests, 0);
    expect(words, hasLength(10));
    expect(words.first.word, 'saved0');
  });

  test(
    'exhausted pool is reported without immediate app retries or secret errors',
    () async {
      var calls = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 429,
                  data: {
                    'code': 'AI_QUOTA_EXHAUSTED',
                    'scope': 'shared',
                    'error': 'private-provider-key',
                  },
                ),
              ),
            );
          },
        ),
      );
      await expectLater(
        reply(),
        throwsA(
          isA<AiQuotaException>().having(
            (error) => error.message,
            'message',
            'AI limit reached. All available Gemini keys are at their limit.',
          ),
        ),
      );
      expect(calls, 1);
    },
  );

  test('global service limits are distinguished from Gemini quota', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 429,
                data: {'code': 'GATEWAY_DAILY_LIMIT'},
              ),
            ),
          );
        },
      ),
    );
    await expectLater(
      reply(),
      throwsA(
        isA<AiQuotaException>().having(
          (error) => error.message,
          'message',
          'TalkMile daily service limit reached.',
        ),
      ),
    );
  });

  test('personal keys still use only their own credential header', () async {
    await store.setGeminiApiKey('personal-key');
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.headers['X-Gemini-API-Key'], 'personal-key');
          expect(options.headers['Authorization'], isNull);
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 429,
                data: {'scope': 'personal'},
              ),
            ),
          );
        },
      ),
    );
    await expectLater(
      reply(),
      throwsA(
        isA<AiQuotaException>().having(
          (error) => error.message,
          'message',
          'Your Gemini API limit is reached.',
        ),
      ),
    );
  });
}
