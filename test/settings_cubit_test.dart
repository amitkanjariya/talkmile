import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'settings uses the fixed gateway and saves only the access token',
    () async {
      SharedPreferences.setMockInitialValues({
        'gatewayUrl': 'https://old.example',
      });
      FlutterSecureStorage.setMockInitialValues({});
      final store = LocalStore(NativeDatabase.memory());
      await store.open();
      final cubit = SettingsCubit(store);

      await cubit.load();
      expect(cubit.state.gatewayConfigured, isFalse);
      expect(store.gatewayUrl, LocalStore.fixedGatewayUrl);

      await cubit.configureGateway('  private-token  ');
      expect(await store.getGatewayToken(), 'private-token');
      expect(cubit.state.gatewayConfigured, isTrue);
      expect(store.gatewayUrl, LocalStore.fixedGatewayUrl);

      await cubit.close();
      await store.close();
    },
  );
}
