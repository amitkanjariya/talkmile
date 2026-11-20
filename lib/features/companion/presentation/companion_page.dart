import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/core/audio/voice_service.dart';
import 'package:talkmile/features/home/domain/practice_catalog.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key});
  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  String notice =
      'Voice depends on the English voices installed on your phone.';

  Future<void> preview(CoachPersona persona) async {
    try {
      final voice = GetIt.I<VoiceService>();
      final message = await voice.preview(persona.gender);
      if (mounted) setState(() => notice = message);
    } catch (error) {
      if (mounted) setState(() => notice = 'Voice preview unavailable.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<SettingsCubit>().state.companion;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Speaking partners')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Choose someone to talk with. You can change any time.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final persona in coachPersonas)
            Card(
              margin: const EdgeInsets.only(bottom: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: selected == persona.id
                      ? colors.primary
                      : colors.outlineVariant,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () =>
                    context.read<SettingsCubit>().chooseCompanion(persona.id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: Text(persona.name.characters.first),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              persona.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${persona.age} · ${persona.role} · ${persona.style}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Preview voice',
                        onPressed: () => preview(persona),
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(notice, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
