import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/core/widgets/brand.dart';

void main() {
  test('light theme headings use a readable foreground color', () {
    final theme = AppTheme.light;
    final foreground = theme.colorScheme.onSurface;
    expect(theme.textTheme.displayLarge?.color, foreground);
    expect(theme.textTheme.headlineMedium?.color, foreground);
    expect(theme.textTheme.titleLarge?.color, foreground);
    expect(theme.textTheme.bodyLarge?.color, foreground);
  });

  testWidgets('section labels use the dark green light-theme accent', (
    tester,
  ) async {
    final theme = AppTheme.light;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: SectionLabel('Settings')),
      ),
    );
    final label = tester.widget<Text>(find.text('SETTINGS'));
    expect(label.style?.color, theme.colorScheme.primary);
  });
}
