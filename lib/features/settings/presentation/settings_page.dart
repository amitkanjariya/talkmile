import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/core/audio/voice_service.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/widgets/brand.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final apiKey = TextEditingController();
  String? message;

  @override
  void dispose() {
    apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsCubit>().state;
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          const SectionLabel('Conversation'),
          const SizedBox(height: 14),
          _choice('Speaking partner', state.companion, [
            'mira',
            'arun',
            'leena',
            'kabir',
            'nisha',
            'dev',
            'sara',
            'imran',
            'tara',
            'rohan',
          ], cubit.chooseCompanion),
          _choice('Appearance', state.themeMode, [
            'system',
            'light',
            'dark',
          ], cubit.changeThemeMode),
          _choice('Difficulty', state.difficulty, [
            'beginner',
            'intermediate',
            'advanced',
          ], cubit.changeDifficulty),
          _choice('Experience', state.mode, [
            'conversation',
            'story',
            'roleplay',
          ], cubit.changeMode),
          _choice(
            'In-turn corrections',
            state.correctionFrequency,
            ['minimal', 'gentle', 'frequent'],
            cubit.changeCorrections,
          ),
          const SizedBox(height: 14),
          Text('Voice speed', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: state.speechRate,
            min: .4,
            max: .8,
            onChanged: cubit.changeRate,
          ),
          const SizedBox(height: 28),
          const SectionLabel('AI access'),
          const SizedBox(height: 12),
          Text(
            'Optional · blank uses TalkMile shared keys.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: apiKey,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: state.geminiKeyConfigured
                  ? 'Replace Gemini API key'
                  : 'Gemini API key (optional)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              try {
                await cubit.configureGeminiKey(apiKey.text);
                if (!mounted) return;
                final usingShared = apiKey.text.trim().isEmpty;
                apiKey.clear();
                setState(
                  () => message = usingShared
                      ? 'Using TalkMile shared access.'
                      : 'Your Gemini API key was saved on this device.',
                );
              } catch (error) {
                if (!mounted) return;
                setState(() => message = error.toString());
              }
            },
            child: const Text('Save'),
          ),
          if (message != null)
            Text(
              message!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          const SizedBox(height: 26),
          const SectionLabel('Permissions'),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, bool>>(
            future: GetIt.I<VoiceService>().permissionStatus(),
            builder: (context, snapshot) {
              final status = snapshot.data;
              if (status == null) {
                return Text(
                  'Checking…',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Microphone: ${status['microphone'] == true ? 'Allowed' : 'Not allowed'}',
                  ),
                  Text(
                    'Notifications: ${status['notification'] == true ? 'Allowed' : 'Not allowed'}',
                  ),
                  Text(
                    'Background audio: ${status['batteryOptimization'] == true ? 'Allowed' : 'Needs access'}',
                  ),
                  TextButton(
                    onPressed: () async {
                      final allowed = await GetIt.I<VoiceService>()
                          .requestBackgroundBatteryAccess();
                      if (!context.mounted) return;
                      setState(
                        () => message = allowed
                            ? 'Screen-off battery access is enabled.'
                            : 'Allow background audio in Android settings.',
                      );
                    },
                    child: const Text('Background audio access'),
                  ),
                  TextButton(
                    onPressed: GetIt.I<VoiceService>().openAppSettings,
                    child: const Text('Open Android app permissions'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 15),
          OutlinedButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete learning data?'),
                  content: const Text(
                    'Delete practice totals and saved story?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await GetIt.I<LocalStore>().deleteLearningData();
                if (context.mounted) context.pop();
              }
            },
            child: const Text('Delete local learning data'),
          ),
        ],
      ),
    );
  }

  Widget _choice(
    String label,
    String value,
    List<String> options,
    Future<void> Function(String) onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(option[0].toUpperCase() + option.substring(1)),
            ),
          )
          .toList(),
      onChanged: (option) {
        if (option != null) onChanged(option);
      },
    ),
  );
}
