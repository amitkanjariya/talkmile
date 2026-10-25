import 'dart:convert';

enum SessionPhase {
  idle,
  initializing,
  listening,
  processing,
  speaking,
  temporarilyPaused,
  recovering,
  stopped,
  error,
}

class CoachResponse {
  const CoachResponse({
    required this.spokenText,
    required this.nextQuestion,
    required this.storyState,
    required this.difficulty,
    this.correction,
    this.vocabulary = const [],
  });
  final String spokenText;
  final String nextQuestion;
  final String storyState;
  final String difficulty;
  final String? correction;
  final List<String> vocabulary;

  factory CoachResponse.fromJson(Object? value) {
    final data = value is String ? jsonDecode(value) : value;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid AI response.');
    }
    final spoken = data['spokenText'];
    final question = data['nextQuestion'];
    if (spoken is! String ||
        spoken.trim().isEmpty ||
        spoken.length > 1200 ||
        question is! String ||
        question.length > 400) {
      throw const FormatException('AI response is incomplete.');
    }
    final correction = data['correction'];
    final improved = correction is Map ? correction['improved'] : null;
    return CoachResponse(
      spokenText: spoken.trim(),
      nextQuestion: question.trim(),
      storyState: data['storyState'] is String
          ? (data['storyState'] as String).substring(
              0,
              (data['storyState'] as String).length.clamp(0, 2000),
            )
          : '',
      difficulty: data['difficulty'] is String
          ? data['difficulty'] as String
          : 'intermediate',
      correction: improved is String && improved.isNotEmpty ? improved : null,
      vocabulary: data['newVocabulary'] is List
          ? (data['newVocabulary'] as List).whereType<String>().take(5).toList()
          : const [],
    );
  }

  String get speech =>
      nextQuestion.isEmpty ? spokenText : '$spokenText $nextQuestion';
}

class ConversationState {
  const ConversationState({
    this.phase = SessionPhase.idle,
    this.topic = 'Open conversation',
    this.spokenText = '',
    this.status = 'Ready when you are',
    this.voiceNotice = '',
    this.elapsed = Duration.zero,
    this.turns = 0,
  });
  final SessionPhase phase;
  final String topic;
  final String spokenText;
  final String status;
  final String voiceNotice;
  final Duration elapsed;
  final int turns;

  ConversationState copyWith({
    SessionPhase? phase,
    String? topic,
    String? spokenText,
    String? status,
    String? voiceNotice,
    Duration? elapsed,
    int? turns,
  }) => ConversationState(
    phase: phase ?? this.phase,
    topic: topic ?? this.topic,
    spokenText: spokenText ?? this.spokenText,
    status: status ?? this.status,
    voiceNotice: voiceNotice ?? this.voiceNotice,
    elapsed: elapsed ?? this.elapsed,
    turns: turns ?? this.turns,
  );
}
