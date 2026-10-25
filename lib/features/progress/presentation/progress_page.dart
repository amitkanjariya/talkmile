import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/core/widgets/brand.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your progress'),
      backgroundColor: Colors.transparent,
    ),
    body: FutureBuilder<ProgressSummary>(
      future: GetIt.I<LocalStore>().progress(),
      builder: (context, snapshot) {
        final progress = snapshot.data;
        if (progress == null) {
          return const Center(child: CircularProgressIndicator());
        }
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
            const Text(
              'Vocabulary and grammar summaries will appear when verified session insights are available.',
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
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
