import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:talkmile/core/data/local_store.dart';
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
            Text(
              progress.seconds == 0
                  ? '0 minutes'
                  : '${(progress.seconds / 60).round()} minutes',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 25),
            _stat(context, 'Turns', '${progress.turns}'),
            _stat(context, 'Days', '${progress.days}'),
            _stat(context, 'Story chapters', '${progress.chapters}'),
            const SizedBox(height: 18),
            const SectionLabel('Vocabulary'),
            const SizedBox(height: 12),
            if (insights.vocabulary.isEmpty)
              Text(
                'No words yet',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final word in insights.vocabulary.keys.take(12))
                    Chip(label: Text(word)),
                ],
              ),
            const SizedBox(height: 24),
            const SectionLabel('Corrections'),
            const SizedBox(height: 12),
            if (insights.corrections.isEmpty)
              Text(
                'No corrections yet',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final correction in insights.corrections.take(3))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(correction),
                  ),
                ),
          ],
        );
      },
    ),
  );

  Widget _stat(BuildContext context, String label, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}
