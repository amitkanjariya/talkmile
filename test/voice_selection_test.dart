import 'package:flutter_test/flutter_test.dart';
import 'package:talkmile/core/audio/voice_service.dart';

void main() {
  test('prefers Indian English and a matching companion name', () {
    const voices = [
      CompanionVoice('US Male', 'en-US', false),
      CompanionVoice('India Female', 'en_IN', false),
      CompanionVoice('India Male', 'en-IN', false),
    ];

    expect(chooseCompanionVoice(voices, 'male')?.name, 'India Male');
    expect(chooseCompanionVoice(voices, 'female')?.name, 'India Female');
  });

  test('chooses an installed English voice when Indian English is absent', () {
    const voices = [
      CompanionVoice('French', 'fr-FR', false),
      CompanionVoice('US Male', 'en-US', false),
      CompanionVoice('British Female', 'en_GB', false),
    ];

    expect(chooseCompanionVoice(voices, 'female')?.name, 'British Female');
  });

  test('gender hints take priority over locale preference', () {
    const voices = [
      CompanionVoice('en-in-x-ena-local', 'en-IN', false),
      CompanionVoice('en-us-x-sfg#female_1-local', 'en-US', false),
      CompanionVoice('en-us-x-sfg#male_1-local', 'en-US', false),
    ];

    expect(
      chooseCompanionVoice(voices, 'male')?.name,
      'en-us-x-sfg#male_1-local',
    );
    expect(
      chooseCompanionVoice(voices, 'female')?.name,
      'en-us-x-sfg#female_1-local',
    );
  });

  test('does not mistake the male substring inside female for male', () {
    expect(
      companionVoiceGender(
        const CompanionVoice('English female voice', 'en-IN', false),
      ),
      'female',
    );
  });

  test('does not treat non-English voices as an English fallback', () {
    const voices = [CompanionVoice('Hindi', 'hi-IN', false)];
    expect(chooseCompanionVoice(voices, 'female'), isNull);
  });
}
