import 'package:dio/dio.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/features/conversation/domain/conversation_models.dart';
import 'package:talkmile/features/home/domain/practice_catalog.dart';

class AiQuotaException implements Exception {
  const AiQuotaException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AiGatewayPort {
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
  });
}

class AiGateway implements AiGatewayPort {
  AiGateway([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 35),
              sendTimeout: const Duration(seconds: 10),
            ),
          );
  final Dio _dio;

  Future<List<DailyWord>> dailyWords(LocalStore store) async {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final cached = await store.readDailyWordSet(date);
    if (cached != null) return cached.map(DailyWord.fromJson).toList();

    final url = store.gatewayUrl;
    final headers = await store.gatewayHeaders();
    if (url.isEmpty) {
      throw StateError('The TalkMile AI service is unavailable.');
    }
    final configured = Uri.parse(url);
    final basePath = configured.path
        .replaceFirst(RegExp(r'/v1/reply/?$'), '')
        .replaceFirst(RegExp(r'/$'), '');
    final vocabularyUri = configured.replace(path: '$basePath/v1/vocabulary');
    final response = await _dio.post<Map<String, dynamic>>(
      vocabularyUri.toString(),
      data: {'date': date, 'difficulty': store.difficulty},
      options: Options(headers: headers),
    );
    final words = response.data?['words'];
    if (words is! List || words.length != 10) {
      throw const FormatException('Daily words are unavailable.');
    }
    final dailyWords = words
        .whereType<Map<String, dynamic>>()
        .map(DailyWord.fromJson)
        .toList();
    await store.saveDailyWordSet(date, [
      for (final word in dailyWords)
        {'word': word.word, 'meaning': word.meaning, 'example': word.example},
    ]);
    return dailyWords;
  }

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
    final url = store.gatewayUrl;
    final headers = await store.gatewayHeaders();
    if (url.isEmpty) {
      throw StateError('The TalkMile AI service is unavailable.');
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          url,
          data: {
            'utterance': utterance,
            'mode': mode,
            'difficulty': difficulty,
            'corrections': corrections,
            'storyState': storyState,
            'persona': persona,
            'correctionReview': correctionReview,
            'correctionHistory': correctionHistory.take(16).toList(),
            'reviewWords': reviewWords.take(10).toList(),
            'recentTurns': recentTurns.take(8).toList(),
          },
          options: Options(headers: headers),
          cancelToken: cancelToken,
        );
        return CoachResponse.fromJson(response.data);
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) rethrow;
        final code = error.response?.statusCode;
        if (code == 401) {
          throw StateError(
            'Gemini API key was rejected. Check your key in Settings.',
          );
        }
        if (code == 429) {
          final data = error.response?.data;
          final gatewayCode = data is Map ? data['code'] : null;
          if (gatewayCode == 'GATEWAY_DAILY_LIMIT') {
            throw const AiQuotaException(
              'TalkMile daily service limit reached.',
            );
          }
          // Use fixed messages instead of rendering arbitrary provider errors.
          final poolExhausted =
              headers.containsKey('Authorization') ||
              (data is Map && data['scope'] == 'shared');
          throw AiQuotaException(
            poolExhausted
                ? 'AI limit reached. All available Gemini keys are at their limit.'
                : 'Your Gemini API limit is reached.',
          );
        }
        if (attempt == 2 || (code != null && code < 500)) {
          throw StateError(
            'The AI connection is unavailable. Check your network and gateway.',
          );
        }
        await Future<void>.delayed(
          Duration(milliseconds: 600 * (1 << attempt)),
        );
      }
    }
    throw StateError('The AI connection is unavailable.');
  }
}
