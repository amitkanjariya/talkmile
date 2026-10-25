import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/core/audio/voice_service.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/core/widgets/brand.dart';
import 'package:talkmile/features/onboarding/domain/onboarding_command.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int step = 0;
  int _guideToken = 0;
  bool _guideActive = false;
  String _guideStatus = '';
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

  Future<void> _advance() async {
    if (step < items.length - 1) {
      setState(() => step++);
    } else {
      ++_guideToken;
      await GetIt.I<VoiceService>().cancelGuide();
      await GetIt.I<LocalStore>().setOnboarded();
      if (mounted) context.go('/companion');
    }
  }

  Future<void> _stopGuide() async {
    ++_guideToken;
    if (mounted) setState(() { _guideActive = false; _guideStatus = ''; });
    await GetIt.I<VoiceService>().cancelGuide();
  }

  Future<void> _startGuide() async {
    final token = ++_guideToken;
    setState(() { _guideActive = true; _guideStatus = 'Preparing voice guide'; });
    final voice = GetIt.I<VoiceService>();
    try {
      await voice.initialize();
      await voice.selectVoice('female');
      while (mounted && token == _guideToken) {
        setState(() => _guideStatus = 'Explaining step ${step + 1}');
        await voice.speak('${items[step].$2}. ${items[step].$3} '
            'Say next, back, or repeat.');
        if (!mounted || token != _guideToken) break;
        setState(() => _guideStatus = 'Listening for next, back, or repeat');
        final heard = await voice.listen();
        if (!mounted || token != _guideToken) break;
        switch (interpretOnboardingCommand(heard ?? '')) {
          case OnboardingCommand.next:
            await _advance();
          case OnboardingCommand.back:
            if (step > 0) setState(() => step--);
          case OnboardingCommand.repeat:
            break;
          case null:
            await voice.speak('Say next, back, or repeat.');
        }
      }
    } catch (error) {
      if (mounted && token == _guideToken) {
        setState(() => _guideStatus = 'Voice guide unavailable. You can use Continue.');
      }
    } finally {
      if (mounted && token == _guideToken) {
        setState(() => _guideActive = false);
      }
    }
  }

  @override
  void dispose() {
    ++_guideToken;
    unawaited(GetIt.I<VoiceService>().cancelGuide());
    super.dispose();
  }

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
              if (_guideStatus.isNotEmpty) ...[
                Text(_guideStatus, style: const TextStyle(color: AppColors.brass)),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: _guideActive ? _stopGuide : _startGuide,
                icon: Icon(_guideActive ? Icons.stop_rounded : Icons.mic_none_rounded),
                label: Text(_guideActive ? 'Stop voice guide' : 'Use voice guide'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _advance,
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
