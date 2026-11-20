import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/widgets/brand.dart';
import 'package:talkmile/features/conversation/presentation/conversation_cubit.dart';
import 'package:talkmile/features/home/domain/practice_catalog.dart';
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
    final companion = context.watch<SettingsCubit>().state.companion;
    final coachName = personaFor(companion).name;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
          children: [
            Row(
              children: [
                const BrandMark(),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/progress'),
                  child: const Text('Progress'),
                ),
                TextButton(
                  onPressed: () => context.push('/settings'),
                  child: const Text('Settings'),
                ),
              ],
            ),
            const SizedBox(height: 38),
            Text(greeting, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 5),
            Text('Let’s talk.', style: theme.textTheme.displayLarge),
            const SizedBox(height: 25),
            FilledButton(
              onPressed: () => _start(context),
              child: const Text('Start speaking'),
            ),
            const SizedBox(height: 12),
            Text(
              '$coachName is ready. Use TalkMile while safely parked.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            _SectionHeading(
              title: 'Today’s words',
              action: TextButton(
                onPressed: () => context.push('/vocabulary'),
                child: const Text('See all'),
              ),
            ),
            _HomeCard(
              title: '10 words for everyday English',
              subtitle: 'Learn a few, then use them in a conversation.',
              onTap: () => context.push('/vocabulary'),
            ),
            const SizedBox(height: 24),
            _SectionHeading(
              title: 'Choose a conversation',
              action: TextButton(
                onPressed: () => context.push('/topics'),
                child: const Text('All topics'),
              ),
            ),
            _HomeCard(
              title: 'Everyday topics',
              subtitle: 'Work, travel, family, and more.',
              onTap: () => context.push('/topics'),
            ),
            const SizedBox(height: 11),
            _HomeCard(
              title: 'Stories',
              subtitle: 'Choose a genre and shape what happens.',
              onTap: () => context.push('/stories'),
            ),
            FutureBuilder<Map<String, dynamic>?>(
              future: GetIt.I<LocalStore>().readStory(),
              builder: (context, snapshot) {
                final saved = snapshot.data;
                if (saved == null ||
                    (saved['storyState'] as String? ?? '').isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _HomeCard(
                    title: 'Continue your story',
                    subtitle:
                        saved['topic'] as String? ??
                        'Pick up where you left off.',
                    onTap: () => _start(context, 'Continue previous story'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _SectionHeading(
              title: 'Your speaking partner',
              action: TextButton(
                onPressed: () => context.push('/companion'),
                child: const Text('Choose'),
              ),
            ),
            _HomeCard(
              title: coachName,
              subtitle: 'Change partner, voice, or conversation style.',
              onTap: () => context.push('/companion'),
            ),
            const SizedBox(height: 24),
            FutureBuilder<ProgressSummary>(
              future: GetIt.I<LocalStore>().progress(),
              builder: (context, snapshot) {
                final progress = snapshot.data;
                if (progress == null || progress.seconds == 0) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${(progress.seconds / 60).round()} minutes spoken · ${progress.days} practice days',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, [String? topic]) async {
    await context.read<ConversationCubit>().start(topic: topic);
    if (context.mounted) context.push('/conversation');
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.action});
  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      action,
    ],
  );
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    ),
  );
}
