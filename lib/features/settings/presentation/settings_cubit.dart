import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talkmile/core/data/local_store.dart';

class SettingsState {
  const SettingsState({
    this.ready = false,
    this.companion = 'mira',
    this.speechRate = .62,
    this.difficulty = 'intermediate',
    this.mode = 'conversation',
    this.correctionFrequency = 'gentle',
    this.themeMode = 'system',
    this.geminiKeyConfigured = false,
  });
  final bool ready;
  final String companion;
  final double speechRate;
  final String difficulty;
  final String mode;
  final String correctionFrequency;
  final String themeMode;
  final bool geminiKeyConfigured;
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this.store) : super(const SettingsState());
  final LocalStore store;

  Future<void> load() async => emit(
    SettingsState(
      ready: true,
      companion: store.companion,
      speechRate: store.speechRate,
      difficulty: store.difficulty,
      mode: store.mode,
      correctionFrequency: store.correctionFrequency,
      themeMode: store.themeMode,
      geminiKeyConfigured: (await store.getGeminiApiKey()).isNotEmpty,
    ),
  );

  Future<void> chooseCompanion(String value) async {
    await store.setCompanion(value);
    await load();
  }

  Future<void> changeRate(double value) async {
    await store.setSpeechRate(value);
    await load();
  }

  Future<void> changeDifficulty(String value) async {
    await store.setDifficulty(value);
    await load();
  }

  Future<void> changeMode(String value) async {
    await store.setMode(value);
    await load();
  }

  Future<void> changeCorrections(String value) async {
    await store.setCorrectionFrequency(value);
    await load();
  }

  Future<void> changeThemeMode(String value) async {
    await store.setThemeMode(value);
    await load();
  }

  Future<void> configureGeminiKey(String apiKey) async {
    final key = apiKey.trim();
    if (key.length > 256 || key.contains(RegExp(r'\s'))) {
      throw const FormatException('That Gemini API key does not look valid.');
    }
    await store.setGeminiApiKey(key);
    await load();
  }
}
