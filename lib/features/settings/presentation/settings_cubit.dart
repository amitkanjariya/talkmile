import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talkmile/core/data/local_store.dart';

class SettingsState {
  const SettingsState({
    this.ready = false,
    this.companion = 'female',
    this.speechRate = .48,
    this.difficulty = 'intermediate',
    this.mode = 'conversation',
    this.correctionFrequency = 'gentle',
    this.gatewayUrl = '',
    this.gatewayConfigured = false,
  });
  final bool ready;
  final String companion;
  final double speechRate;
  final String difficulty;
  final String mode;
  final String correctionFrequency;
  final String gatewayUrl;
  final bool gatewayConfigured;
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
      gatewayUrl: store.gatewayUrl,
      gatewayConfigured:
          store.gatewayUrl.isNotEmpty &&
          (await store.getGatewayToken()).isNotEmpty,
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

  Future<void> configureGateway(String url, String token) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Enter a valid HTTPS gateway URL.');
    }
    if (token.trim().isEmpty) {
      throw const FormatException('Enter the gateway access token.');
    }
    await store.setGatewayUrl(uri.toString());
    await store.setGatewayToken(token.trim());
    await load();
  }
}
