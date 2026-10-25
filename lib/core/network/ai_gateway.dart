import 'package:dio/dio.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/features/conversation/domain/conversation_models.dart';

abstract interface class AiGatewayPort {
  Future<CoachResponse> reply({
    required LocalStore store,
    required String utterance,
    required String mode,
    required String difficulty,
    required String corrections,
    required String storyState,
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

  @override
  Future<CoachResponse> reply({
    required LocalStore store,
    required String utterance,
    required String mode,
    required String difficulty,
    required String corrections,
    required String storyState,
    required List<Map<String, String>> recentTurns,
    required CancelToken cancelToken,
  }) async {
    final url = store.gatewayUrl;
    final token = await store.getGatewayToken();
    if (url.isEmpty || token.isEmpty) {
      throw StateError(
        'Configure your private Gemini gateway in Settings before starting.',
      );
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
            'recentTurns': recentTurns.take(8).toList(),
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}),
          cancelToken: cancelToken,
        );
        return CoachResponse.fromJson(response.data);
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) rethrow;
        final code = error.response?.statusCode;
        if (code == 401) {
          throw StateError('Gateway access was rejected. Check Settings.');
        }
        if (code == 429) {
          throw StateError(
            'The AI quota is currently exhausted. Try again later.',
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
