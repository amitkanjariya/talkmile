import 'package:flutter_test/flutter_test.dart';
import 'package:talkmile/features/conversation/domain/conversation_models.dart';
import 'package:talkmile/features/conversation/domain/voice_command.dart';

void main() {
  test('voice commands recognize natural variants', () {
    expect(interpretVoiceCommand('Please repeat that.'), VoiceCommand.repeat);
    expect(
      interpretVoiceCommand('Can you speak more slowly?'),
      VoiceCommand.slower,
    );
    expect(
      interpretVoiceCommand('Switch to the female voice.'),
      VoiceCommand.female,
    );
    expect(interpretVoiceCommand('I went to the market.'), isNull);
  });

  test('AI response validates speech and preserves structured fields', () {
    final reply = CoachResponse.fromJson({
      'spokenText': 'That sounds interesting.',
      'nextQuestion': 'What happened next?',
      'correction': {'improved': 'I went to the market.'},
      'storyState': 'The user is at a café.',
      'chapterCompleted': true,
      'newVocabulary': ['curious'],
      'difficulty': 'beginner',
    });
    expect(reply.speech, 'That sounds interesting. What happened next?');
    expect(reply.correction, 'I went to the market.');
    expect(reply.vocabulary, ['curious']);
    expect(reply.chapterCompleted, isTrue);
  });

  test('AI response rejects missing spoken text', () {
    expect(
      () => CoachResponse.fromJson({'spokenText': '', 'nextQuestion': ''}),
      throwsFormatException,
    );
  });
}
