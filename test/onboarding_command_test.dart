import 'package:flutter_test/flutter_test.dart';
import 'package:talkmile/features/onboarding/domain/onboarding_command.dart';

void main() {
  test('voice guide recognizes navigation without matching unrelated speech', () {
    expect(interpretOnboardingCommand('Please continue.'), OnboardingCommand.next);
    expect(interpretOnboardingCommand('Go back'), OnboardingCommand.back);
    expect(interpretOnboardingCommand('Say that again'), OnboardingCommand.repeat);
    expect(interpretOnboardingCommand('I like this story'), isNull);
  });
}
