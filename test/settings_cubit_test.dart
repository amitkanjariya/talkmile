import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Gemini key is optional and a blank value selects shared access',
    () async {
      SharedPreferences.setMockInitialValues({
        'gatewayUrl': 'https://old.example',
      });
      FlutterSecureStorage.setMockInitialValues({});
      final store = LocalStore(NativeDatabase.memory());
      await store.open();
      final cubit = SettingsCubit(store);
      await cubit.load();

      expect(cubit.state.geminiKeyConfigured, isFalse);
      expect(await store.gatewayHeaders(), isEmpty);
      expect(store.gatewayUrl, LocalStore.fixedGatewayUrl);
      await cubit.configureGeminiKey('');
      expect(cubit.state.geminiKeyConfigured, isFalse);
      expect(await store.gatewayHeaders(), isEmpty);
      expect(store.gatewayUrl, LocalStore.fixedGatewayUrl);
      await cubit.close();
      await store.close();
    },
  );

  test(
    'personal key is saved securely and remains the only request credential',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({
        'gatewayToken': 'old-shared-code',
      });
      final store = LocalStore(NativeDatabase.memory());
      await store.open();
      final cubit = SettingsCubit(store);
      await cubit.load();
      await cubit.configureGeminiKey('  private-api-key  ');
      expect(await store.getGeminiApiKey(), 'private-api-key');
      expect(cubit.state.geminiKeyConfigured, isTrue);
      expect(await store.gatewayHeaders(), {
        'X-Gemini-API-Key': 'private-api-key',
      });
      await cubit.configureGeminiKey('');
      expect(await store.getGeminiApiKey(), '');
      expect(cubit.state.geminiKeyConfigured, isFalse);
      expect(await store.gatewayHeaders(), isEmpty);
      await cubit.close();
      await store.close();
    },
  );

  test('rejects malformed personal keys without saving them', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final store = LocalStore(NativeDatabase.memory());
    await store.open();
    final cubit = SettingsCubit(store);
    await expectLater(
      cubit.configureGeminiKey('not a key'),
      throwsFormatException,
    );
    expect(await store.getGeminiApiKey(), isEmpty);
    await cubit.close();
    await store.close();
  });
}
