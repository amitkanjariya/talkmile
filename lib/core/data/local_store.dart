import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps aggregate progress in SQLite. Conversation text and gateway credentials
/// live in Android-backed secure storage, never in the unencrypted database.
class LocalStore extends GeneratedDatabase {
  static const fixedGatewayUrl =
      'https://talkmile-gateway.amitkanjariya28.workers.dev/v1/reply';

  LocalStore([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'talkmile'));

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
    await _preferences.remove('gatewayUrl');
    if (_preferences.getBool('speechSpeedImproved') != true) {
      final saved = _preferences.getDouble('speechRate');
      if (saved == null || saved <= .48) {
        await _preferences.setDouble('speechRate', .62);
      }
      await _preferences.setBool('speechSpeedImproved', true);
    }
    await customSelect('SELECT 1').get();
  }

  String get companion {
    final value = _preferences.getString('companion') ?? 'mira';
    return value == 'female'
        ? 'mira'
        : value == 'male'
        ? 'arun'
        : value;
  }

  Future<void> setCompanion(String value) =>
      _preferences.setString('companion', value);
  double get speechRate => _preferences.getDouble('speechRate') ?? .62;

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
  String get themeMode => _preferences.getString('themeMode') ?? 'system';
  Future<void> setThemeMode(String value) =>
      _preferences.setString('themeMode', value);

  Future<void> saveSessionResume({
    required String topic,
    required String utterance,
  }) async {
    // Write the resume payload before setting the active flag so a crash during
    // the first write cannot leave a partially initialized session to restore.
    await _preferences.setString('sessionResumeTopic', topic);
    await _preferences.setString('sessionResumeUtterance', utterance);
    await _preferences.setBool('sessionResumeActive', true);
  }

  SessionResume? get sessionResume {
    if (_preferences.getBool('sessionResumeActive') != true) return null;
    final topic = _preferences.getString('sessionResumeTopic');
    final utterance = _preferences.getString('sessionResumeUtterance');
    if (topic == null || utterance == null || utterance.isEmpty) return null;
    return SessionResume(topic: topic, utterance: utterance);
  }

  Future<void> clearSessionResume() async {
    await _preferences.setBool('sessionResumeActive', false);
    await _preferences.remove('sessionResumeTopic');
    await _preferences.remove('sessionResumeUtterance');
  }

  Future<bool> shouldReviewWeeklyVocabulary() async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final key = monday.toIso8601String().substring(0, 10);
    final previous = _preferences.getString('lastVocabularyReviewWeek');
    if (previous == null) {
      await _preferences.setString('lastVocabularyReviewWeek', key);
      return false;
    }
    return previous != key;
  }

  Future<void> markWeeklyVocabularyReview() async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    await _preferences.setString(
      'lastVocabularyReviewWeek',
      monday.toIso8601String().substring(0, 10),
    );
  }

  Future<void> saveDailyWordSet(
    String date,
    List<Map<String, String>> words,
  ) async {
    Map<String, dynamic> history = {};
    final raw = await _secure.read(key: 'dailyWordSets');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) history = decoded;
      } catch (_) {}
    }
    history[date] = words.take(10).toList();
    final dates = history.keys.toList()..sort();
    final removeCount = (dates.length - 14).clamp(0, dates.length).toInt();
    for (final oldDate in dates.take(removeCount)) {
      history.remove(oldDate);
    }
    await _secure.write(key: 'dailyWordSets', value: jsonEncode(history));
  }

  Future<List<Map<String, String>>?> readDailyWordSet(String date) async {
    final raw = await _secure.read(key: 'dailyWordSets');
    if (raw == null) return null;
    try {
      final history = jsonDecode(raw);
      final words = history is Map<String, dynamic> ? history[date] : null;
      if (words is! List || words.length != 10) return null;
      final result = <Map<String, String>>[];
      for (final entry in words) {
        if (entry is! Map ||
            entry['word'] is! String ||
            entry['meaning'] is! String ||
            entry['example'] is! String) {
          return null;
        }
        result.add({
          'word': entry['word'] as String,
          'meaning': entry['meaning'] as String,
          'example': entry['example'] as String,
        });
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> weeklyVocabularyWords() async {
    final raw = await _secure.read(key: 'dailyWordSets');
    if (raw == null) return const [];
    try {
      final history = jsonDecode(raw);
      if (history is! Map<String, dynamic>) return const [];
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final dates =
          history.keys
              .whereType<String>()
              .where((date) => date.compareTo(today) < 0)
              .toList()
            ..sort();
      final result = <String>[];
      for (final date in dates.reversed.take(7)) {
        final words = history[date];
        if (words is List) {
          for (final entry in words) {
            if (entry is Map && entry['word'] is String) {
              result.add(entry['word'] as String);
            }
          }
        }
      }
      return result.toSet().take(10).toList();
    } catch (_) {
      return const [];
    }
  }

  String get gatewayUrl => fixedGatewayUrl;
  Future<String> getGeminiApiKey() async =>
      await _secure.read(key: 'geminiApiKey') ?? '';
  Future<void> setGeminiApiKey(String value) =>
      _secure.write(key: 'geminiApiKey', value: value);
  Future<Map<String, String>> gatewayHeaders() async {
    final key = await getGeminiApiKey();
    return key.isEmpty ? {} : {'X-Gemini-API-Key': key};
  }

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

  Future<LearningInsights> insights() async {
    final raw = await _secure.read(key: 'learningInsights');
    if (raw == null) return const LearningInsights();
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return const LearningInsights();
      final vocabulary = data['vocabulary'];
      final corrections = data['corrections'];
      return LearningInsights(
        vocabulary: vocabulary is Map
            ? vocabulary.map(
                (key, value) => MapEntry('$key', value is int ? value : 0),
              )
            : const {},
        corrections: corrections is List
            ? corrections.whereType<String>().toList()
            : const [],
      );
    } catch (_) {
      return const LearningInsights();
    }
  }

  Future<void> recordInsights(List<String> words, String? correction) async {
    if (words.isEmpty && (correction == null || correction.isEmpty)) return;
    final current = await insights();
    final vocabulary = Map<String, int>.of(current.vocabulary);
    for (final word in words.take(5)) {
      final cleaned = word.trim().toLowerCase();
      if (cleaned.isEmpty || cleaned.length > 50) continue;
      vocabulary[cleaned] = (vocabulary[cleaned] ?? 0) + 1;
    }
    final corrections = List<String>.of(current.corrections);
    if (correction != null && correction.trim().isNotEmpty) {
      final cleaned = correction.trim();
      if (!corrections.contains(cleaned)) corrections.insert(0, cleaned);
    }
    final ranked = vocabulary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    await _secure.write(
      key: 'learningInsights',
      value: jsonEncode({
        'vocabulary': Map.fromEntries(ranked.take(100)),
        'corrections': corrections.take(30).toList(),
      }),
    );
  }

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
    await _secure.delete(key: 'learningInsights');
    await _secure.delete(key: 'dailyWordSets');
  }
}

class LearningInsights {
  const LearningInsights({
    this.vocabulary = const {},
    this.corrections = const [],
  });
  final Map<String, int> vocabulary;
  final List<String> corrections;
}

class SessionResume {
  const SessionResume({required this.topic, required this.utterance});

  final String topic;
  final String utterance;
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
