import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps aggregate progress in SQLite. Conversation text and gateway credentials
/// live in Android-backed secure storage, never in the unencrypted database.
class LocalStore extends GeneratedDatabase {
  LocalStore() : super(driftDatabase(name: 'talkmile'));

  static const _secure = FlutterSecureStorage();
  late final SharedPreferences _preferences;

  @override
  int get schemaVersion => 1;
  @override
  List<TableInfo> get allTables => [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement('''
          CREATE TABLE practice_day (
            day TEXT PRIMARY KEY NOT NULL,
            seconds INTEGER NOT NULL DEFAULT 0,
            turns INTEGER NOT NULL DEFAULT 0,
            chapters INTEGER NOT NULL DEFAULT 0
          )
        ''');
    },
  );

  Future<void> open() async {
    _preferences = await SharedPreferences.getInstance();
    await customSelect('SELECT 1').get();
  }

  bool get onboarded => _preferences.getBool('onboarded') ?? false;
  Future<void> setOnboarded() => _preferences.setBool('onboarded', true);
  String get companion => _preferences.getString('companion') ?? 'female';
  Future<void> setCompanion(String value) =>
      _preferences.setString('companion', value);
  double get speechRate => _preferences.getDouble('speechRate') ?? .48;
  Future<void> setSpeechRate(double value) =>
      _preferences.setDouble('speechRate', value);
  String get difficulty =>
      _preferences.getString('difficulty') ?? 'intermediate';
  Future<void> setDifficulty(String value) =>
      _preferences.setString('difficulty', value);
  String get mode => _preferences.getString('mode') ?? 'conversation';
  Future<void> setMode(String value) => _preferences.setString('mode', value);
  String get correctionFrequency =>
      _preferences.getString('correctionFrequency') ?? 'gentle';
  Future<void> setCorrectionFrequency(String value) =>
      _preferences.setString('correctionFrequency', value);
  String get gatewayUrl => _preferences.getString('gatewayUrl') ?? '';
  Future<void> setGatewayUrl(String value) =>
      _preferences.setString('gatewayUrl', value);
  Future<String> getGatewayToken() async =>
      await _secure.read(key: 'gatewayToken') ?? '';
  Future<void> setGatewayToken(String value) =>
      _secure.write(key: 'gatewayToken', value: value);

  Future<Map<String, dynamic>?> readStory() async {
    final raw = await _secure.read(key: 'storyState');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveStory(Map<String, dynamic> story) =>
      _secure.write(key: 'storyState', value: jsonEncode(story));

  Future<void> addPractice(
    Duration duration,
    int turns, {
    int chapters = 0,
  }) async {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    await customStatement(
      '''
      INSERT INTO practice_day(day, seconds, turns, chapters)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(day) DO UPDATE SET
        seconds = seconds + excluded.seconds,
        turns = turns + excluded.turns,
        chapters = chapters + excluded.chapters
    ''',
      [day, duration.inSeconds, turns, chapters],
    );
  }

  Future<ProgressSummary> progress() async {
    final rows = await customSelect('''
      SELECT COALESCE(SUM(seconds), 0) AS seconds,
             COALESCE(SUM(turns), 0) AS turns,
             COALESCE(SUM(chapters), 0) AS chapters,
             COUNT(*) AS days FROM practice_day
    ''').get();
    final data = rows.single.data;
    return ProgressSummary(
      seconds: data['seconds'] as int,
      turns: data['turns'] as int,
      chapters: data['chapters'] as int,
      days: data['days'] as int,
    );
  }

  Future<void> deleteLearningData() async {
    await customStatement('DELETE FROM practice_day');
    await _secure.delete(key: 'storyState');
  }
}

class ProgressSummary {
  const ProgressSummary({
    required this.seconds,
    required this.turns,
    required this.chapters,
    required this.days,
  });
  final int seconds;
  final int turns;
  final int chapters;
  final int days;
}
