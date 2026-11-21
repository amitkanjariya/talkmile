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
      expect(store.gatewayUrl, LocalStore.fixedGatewayUrl);

      await cubit.close();
      await store.close();
    },
  );
}
