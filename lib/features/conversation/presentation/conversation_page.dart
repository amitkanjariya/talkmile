import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/core/widgets/brand.dart';
import 'package:talkmile/features/conversation/domain/conversation_models.dart';
import 'package:talkmile/features/conversation/presentation/conversation_cubit.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

class ConversationPage extends StatelessWidget {
  const ConversationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConversationCubit>().state;
    final partner = context.watch<SettingsCubit>().state.companion == 'male'
        ? 'Arun'
        : 'Mira';
    final minutes = state.elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (state.elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              Row(
                children: [
                  const BrandMark(size: 27),
                  const Spacer(),
                  Text(
                    '$minutes:$seconds',
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              SectionLabel(state.topic),
              const SizedBox(height: 14),
              Text(
                'Talking with $partner',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              Semantics(
                label: 'Conversation status: ${state.status}',
                child: _AudioMark(phase: state.phase),
              ),
              const SizedBox(height: 32),
              Text(
                state.status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 82,
                child: SingleChildScrollView(
                  child: Text(
                    state.spokenText.isEmpty
                        ? 'A calm space to practise, one conversation at a time.'
                        : state.spokenText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, height: 1.5),
                  ),
                ),
              ),
              if (state.voiceNotice.isNotEmpty)
                Text(
                  state.voiceNotice,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              const Spacer(),
              if (state.phase == SessionPhase.error) ...[
                FilledButton(
                  onPressed: () => context.push('/settings'),
                  child: const Text('Open settings'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async {
                    await context.read<ConversationCubit>().start(
                      topic: state.topic,
                    );
                  },
                  child: const Text('Try again'),
                ),
              ] else if (state.phase == SessionPhase.stopped)
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to home'),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brass,
                    foregroundColor: AppColors.ink,
                  ),
                  onPressed: () => context.read<ConversationCubit>().stop(),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('End session'),
                ),
              const SizedBox(height: 12),
              const Text(
                'Keep your eyes on the road. Use your voice during the session.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioMark extends StatelessWidget {
  const _AudioMark({required this.phase});
  final SessionPhase phase;
  @override
  Widget build(BuildContext context) {
    final active =
        phase == SessionPhase.listening || phase == SessionPhase.speaking;
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppColors.brass : AppColors.border,
          width: 1.5,
        ),
        color: AppColors.midnight,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final height in [22.0, 42, 68, 48, 28, 50, 30])
              Container(
                width: 5,
                height: active ? height.toDouble() : 12,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: active ? AppColors.brass : AppColors.muted,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
