import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talkmile/core/data/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('records only real vocabulary and corrections, then deletes them', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final store = LocalStore(NativeDatabase.memory());
    await store.open();
    await store.recordInsights(['Curious', 'curious', 'journey'],
        'I went to the market.');
    final insights = await store.insights();
    expect(insights.vocabulary['curious'], 2);
    expect(insights.vocabulary['journey'], 1);
    expect(insights.corrections, ['I went to the market.']);
    await store.deleteLearningData();
    final cleared = await store.insights();
    expect(cleared.vocabulary, isEmpty);
    expect(cleared.corrections, isEmpty);
    await store.close();
  });
}
