import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'settings uses the fixed gateway and saves a Gemini key securely',
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
      expect(store.gatewayUrl, LocalStore.fixedGatewayUrl);

      await cubit.configureGeminiKey('  private-api-key  ');
      expect(await store.getGeminiApiKey(), 'private-api-key');
      expect(cubit.state.geminiKeyConfigured, isTrue);
      expect(cubit.state.aiAccessMode, 'personal');
      expect(await store.gatewayHeaders(), {
        'X-Gemini-API-Key': 'private-api-key',
      });
      expect(store.gatewayUrl, LocalStore.fixedGatewayUrl);

      await cubit.close();
      await store.close();
    },
  );

  test(
    'shared access switches credentials without deleting the personal key',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({
        'geminiApiKey': 'personal-key',
      });
      final store = LocalStore(NativeDatabase.memory());
      await store.open();
      final cubit = SettingsCubit(store);
      await cubit.load();
      expect(cubit.state.aiAccessMode, 'personal');
      await cubit.configureSharedAccess('  owner-access-code  ');
      expect(cubit.state.aiAccessMode, 'shared');
      expect(cubit.state.sharedAccessConfigured, isTrue);
      expect(await store.gatewayHeaders(), {
        'Authorization': 'Bearer owner-access-code',
      });
      expect(await store.getGeminiApiKey(), 'personal-key');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('gatewayToken'), isNull);
      expect(prefs.getString('geminiApiKey'), isNull);
      await cubit.chooseAiAccessMode('personal');
      expect(await store.gatewayHeaders(), {
        'X-Gemini-API-Key': 'personal-key',
      });
      await cubit.close();
      await store.close();
    },
  );

  test('old access codes keep working after an app update', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'gatewayToken': 'legacy-code'});
    final store = LocalStore(NativeDatabase.memory());
    await store.open();
    expect(await store.getAiAccessMode(), 'shared');
    expect(await store.gatewayHeaders(), {
      'Authorization': 'Bearer legacy-code',
    });
    await store.setAiAccessMode('personal');
    expect(await store.gatewayHeaders(), isEmpty);
    await store.close();
  });
}
