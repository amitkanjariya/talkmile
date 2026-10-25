import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/core/widgets/brand.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  Future<(ProgressSummary, LearningInsights)> _load() async {
    final store = GetIt.I<LocalStore>();
    return (await store.progress(), await store.insights());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your progress'),
      backgroundColor: Colors.transparent,
    ),
    body: FutureBuilder<(ProgressSummary, LearningInsights)>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final (progress, insights) = data;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const BrandMark(size: 27),
            const SizedBox(height: 42),
            const SectionLabel('Every word counts'),
            const SizedBox(height: 12),
            Text(
              progress.seconds == 0
                  ? 'Your journey starts here.'
                  : '${(progress.seconds / 60).round()} minutes of practice',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 25),
            _stat(
              context,
              'Speaking turns',
              '${progress.turns}',
              Icons.record_voice_over_outlined,
            ),
            _stat(
              context,
              'Practice days',
              '${progress.days}',
              Icons.calendar_month_outlined,
            ),
            _stat(
              context,
              'Story chapters',
              '${progress.chapters}',
              Icons.menu_book_outlined,
            ),
            const SizedBox(height: 24),
            Text(
              progress.seconds == 0
                  ? 'Start a conversation to see real activity here.'
                  : 'Keep returning for short conversations. Your time and turns are counted from actual sessions.',
              style: const TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 18),
            const SectionLabel('Practised vocabulary'),
            const SizedBox(height: 12),
            if (insights.vocabulary.isEmpty)
              const Text('Words introduced during your conversations will appear here.',
                  style: TextStyle(color: AppColors.muted))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final word in insights.vocabulary.keys.take(12))
                  Chip(label: Text(word)),
              ]),
            const SizedBox(height: 24),
            const SectionLabel('Grammar improvements'),
            const SizedBox(height: 12),
            if (insights.corrections.isEmpty)
              const Text('Helpful corrections will appear after your coach notices a meaningful mistake.',
                  style: TextStyle(color: AppColors.muted))
            else
              for (final correction in insights.corrections.take(3))
                Card(child: Padding(padding: const EdgeInsets.all(16),
                  child: Text(correction))),
            if (insights.corrections.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionLabel('Try next'),
              const SizedBox(height: 10),
              Text('Use “${insights.corrections.first}” in your next conversation.',
                style: const TextStyle(color: AppColors.muted, height: 1.5)),
            ],
          ],
        );
      },
    ),
  );

  Widget _stat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brass),
          const SizedBox(width: 16),
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}
