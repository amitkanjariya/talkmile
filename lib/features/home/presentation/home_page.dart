import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/core/widgets/brand.dart';
import 'package:talkmile/features/conversation/presentation/conversation_cubit.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final partner = context.watch<SettingsCubit>().state.companion == 'male'
        ? 'Arun'
        : 'Mira';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Row(
              children: [
                const BrandMark(),
                const Spacer(),
                IconButton(
                  tooltip: 'Progress',
                  onPressed: () => context.push('/progress'),
                  icon: const Icon(Icons.insights_outlined),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            const SizedBox(height: 42),
            const SectionLabel('Your daily practice'),
            const SizedBox(height: 14),
            Text(
              '$greeting.\nLet’s talk.',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 14),
            Text(
              '$partner is ready to listen. Start while safely parked, then keep your eyes on the road.',
              style: const TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.midnight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: AppColors.brass,
                    size: 35,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'A conversation that goes with you',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stories, real life practice, and a little progress every day.',
                    style: TextStyle(color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _start(context),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start conversation'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionLabel('Pick up where you left off'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _start(context, 'Continue previous story'),
              icon: const Icon(Icons.bookmark_border_rounded),
              label: const Text('Continue previous story'),
            ),
            const SizedBox(height: 28),
            const SectionLabel('Try a topic'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final topic in [
                  'A job interview',
                  'An unexpected journey',
                  'At the café',
                  'A new business',
                ])
                  ActionChip(
                    label: Text(topic),
                    onPressed: () => _start(context, topic),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            FutureBuilder<ProgressSummary>(
              future: GetIt.I<LocalStore>().progress(),
              builder: (context, snapshot) {
                final progress = snapshot.data;
                return Text(
                  progress == null || progress.seconds == 0
                      ? 'Your practice history will appear here after your first session.'
                      : '${(progress.seconds / 60).round()} minutes spoken across ${progress.days} days',
                  style: const TextStyle(color: AppColors.muted),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, [String? topic]) async {
    final started = await context.read<ConversationCubit>().start(topic: topic);
    if (context.mounted) context.push('/conversation');
    if (!started) return;
  }
}
