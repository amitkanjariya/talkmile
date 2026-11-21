import 'package:flutter_test/flutter_test.dart';
import 'package:talkmile/features/home/domain/practice_catalog.dart';

void main() {
  test(
    'all coach profiles are adults with distinct daily-life relationships',
    () {
      expect(coachPersonas, hasLength(10));
      expect(
        coachPersonas.every((persona) => int.parse(persona.age) >= 18),
        isTrue,
      );
      final roles = coachPersonas.map((persona) => persona.role).toSet();
      expect(
        roles,
        containsAll([
          'male friend',
          'female friend',
          'girlfriend',
          'ex-girlfriend and old friend',
          'wife',
          'college friend',
          'school friend',
          'office colleague',
        ]),
      );
    },
  );
}
