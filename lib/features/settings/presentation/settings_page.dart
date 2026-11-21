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
          const BrandMark(size: 27),
          const SizedBox(height: 30),
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
          Text(
            'Speaking speed: ${(state.speechRate * 100).round()}%',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: state.speechRate,
            min: .3,
            max: .6,
            onChanged: cubit.changeRate,
          ),
          const SizedBox(height: 28),
          const SectionLabel('Your Gemini API key'),
          const SizedBox(height: 12),
          Text(
            'TalkMile stores your key securely on this device and forwards it to Gemini through its gateway. Google free-tier quotas apply; paid usage may be billed to your Google project.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: apiKey,
            obscureText: true,
            decoration: InputDecoration(
              labelText: state.geminiKeyConfigured
                  ? 'Replace Gemini API key'
                  : 'Gemini API key',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              try {
                await cubit.configureGeminiKey(apiKey.text);
                apiKey.clear();
                setState(() => message = 'Gemini API key saved on this device.');
              } catch (error) {
                setState(() => message = error.toString());
              }
            },
            child: const Text('Save Gemini API key'),
          ),
          if (message != null)
            Text(
              message!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          const SizedBox(height: 26),
          const SectionLabel('Privacy'),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, bool>>(
            future: GetIt.I<VoiceService>().permissionStatus(),
            builder: (context, snapshot) {
              final status = snapshot.data;
              if (status == null) {
                return Text(
                  'Checking microphone and notification permissions…',
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
                    'Screen-off access: ${status['batteryOptimization'] == true ? 'Allowed' : 'Needs permission'}',
                  ),
                  TextButton(
                    onPressed: () async {
                      final allowed = await GetIt.I<VoiceService>()
                          .requestBackgroundBatteryAccess();
                      if (!context.mounted) return;
                      setState(
                        () => message = allowed
                            ? 'Screen-off battery access is enabled.'
                            : 'Allow unrestricted battery use in Android settings for screen-off replies.',
                      );
                    },
                    child: const Text('Allow screen-off conversations'),
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
          Text(
            'Speech recognition is provided by your Android speech engine. It may send audio to its provider. TalkMile does not store raw audio.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          OutlinedButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete learning data?'),
                  content: const Text(
                    'This removes your local practice totals and saved story.',
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
