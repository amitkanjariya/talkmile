import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/core/widgets/brand.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int step = 0;
  static const items = [
    (
      Icons.record_voice_over_rounded,
      'Your voice, your choice',
      'Choose one of two AI companions and hear the voice available on your device.',
    ),
    (
      Icons.hearing_rounded,
      'Speak naturally',
      'Talk through stories and real life situations. Listening resumes after every reply.',
    ),
    (
      Icons.auto_graph_rounded,
      'Grow each day',
      'Practise on your commute and return to the story whenever you like.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final item = items[step];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandMark(),
              const Spacer(),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(item.$1, size: 44, color: AppColors.brass),
              ),
              const SizedBox(height: 32),
              SectionLabel('0${step + 1} / 03'),
              const SizedBox(height: 16),
              Text(item.$2, style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 20),
              Text(
                item.$3,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
              const Spacer(),
              const Text(
                'Before riding, choose your companion and grant microphone access while parked.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  if (step < items.length - 1) {
                    setState(() => step++);
                  } else {
                    await GetIt.I<LocalStore>().setOnboarded();
                    if (context.mounted) context.go('/companion');
                  }
                },
                child: Text(
                  step == items.length - 1 ? 'Choose a companion' : 'Continue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
