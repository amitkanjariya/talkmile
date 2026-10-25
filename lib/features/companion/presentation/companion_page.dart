import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/core/audio/voice_service.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/core/widgets/brand.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key});
  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  String notice =
      'Voice availability depends on the speech engine installed on your phone.';

  Future<void> preview(String partner) async {
    try {
      final voice = GetIt.I<VoiceService>();
      final message = await voice.preview(partner);
      if (mounted) setState(() => notice = message);
    } catch (error) {
      if (mounted) {
        setState(() => notice = 'Voice preview is unavailable: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<SettingsCubit>().state.companion;
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(size: 27),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const SectionLabel('Your speaking partner'),
              const SizedBox(height: 14),
              Text(
                'A voice for every mile.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose the company that feels right. You can change it any time.',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 30),
              _partner(
                context,
                'female',
                'Mira',
                'Warm and encouraging',
                Icons.waves_rounded,
                selected == 'female',
              ),
              const SizedBox(height: 14),
              _partner(
                context,
                'male',
                'Arun',
                'Calm and patient',
                Icons.multitrack_audio_rounded,
                selected == 'male',
              ),
              const SizedBox(height: 16),
              Text(
                notice,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Continue to TalkMile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partner(
    BuildContext context,
    String value,
    String name,
    String description,
    IconData icon,
    bool selected,
  ) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: selected ? AppColors.brass : AppColors.border,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.read<SettingsCubit>().chooseCompanion(value),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: AppColors.teal.withValues(alpha: .2),
              child: Icon(icon, color: AppColors.brass),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    description,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Preview $name',
              onPressed: () => preview(value),
              icon: const Icon(Icons.play_circle_outline_rounded),
            ),
          ],
        ),
      ),
    ),
  );
}
