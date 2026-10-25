import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/core/widgets/brand.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final url = TextEditingController();
  final token = TextEditingController();
  String? message;

  @override
  void initState() {
    super.initState();
    url.text = GetIt.I<LocalStore>().gatewayUrl;
  }

  @override
  void dispose() {
    url.dispose();
    token.dispose();
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
          _choice('Companion', state.companion, [
            'female',
            'male',
          ], cubit.chooseCompanion),
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
          _choice('Corrections', state.correctionFrequency, [
            'minimal',
            'gentle',
            'frequent',
          ], cubit.changeCorrections),
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
          const SectionLabel('Private AI gateway'),
          const SizedBox(height: 12),
          const Text(
            'TalkMile sends recognized text to your configured gateway. Your Gemini key stays on the server.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'HTTPS Worker URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: token,
            obscureText: true,
            decoration: InputDecoration(
              labelText: state.gatewayConfigured
                  ? 'Replace gateway access token'
                  : 'Gateway access token',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              try {
                await cubit.configureGateway(url.text, token.text);
                token.clear();
                setState(() => message = 'Gateway settings saved securely.');
              } catch (error) {
                setState(() => message = error.toString());
              }
            },
            child: const Text('Save gateway'),
          ),
          if (message != null)
            Text(message!, style: const TextStyle(color: AppColors.brass)),
          const SizedBox(height: 26),
          const SectionLabel('Privacy'),
          const SizedBox(height: 12),
          const Text(
            'Speech recognition is provided by your Android speech engine. It may send audio to its provider. TalkMile does not store raw audio.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
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
        fillColor: AppColors.midnight,
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
