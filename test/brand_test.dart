import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/core/widgets/brand.dart';

void main() {
  testWidgets('TalkMile brand renders in dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: BrandMark()),
      ),
    );
    expect(find.text('talkmile'), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
  });
}
