import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/features/conversation/presentation/conversation_cubit.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/network/ai_gateway.dart';
import 'package:talkmile/features/home/domain/practice_catalog.dart';

class PracticeLibraryPage extends StatelessWidget {
  const PracticeLibraryPage({super.key, required this.stories});
  final bool stories;

  @override
  Widget build(BuildContext context) {
    final items = stories ? storyPrompts : practiceTopics;
    final groups = items
        .map(
          (e) => stories
              ? (e as StoryPrompt).genre
              : (e as PracticeTopic).category,
        )
        .toSet()
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(stories ? 'Stories' : 'Conversation topics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            stories
                ? 'Choose a story. Your choices shape what happens.'
                : 'Pick something familiar and start talking.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 9, top: 8),
              child: Text(group, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final item in items.where(
              (e) => stories
                  ? (e as StoryPrompt).genre == group
                  : (e as PracticeTopic).category == group,
            ))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _start(
                    context,
                    stories ? item as StoryPrompt : item as PracticeTopic,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stories
                              ? (item as StoryPrompt).title
                              : (item as PracticeTopic).title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (stories) ...[
                          const SizedBox(height: 3),
                          Text(
                            (item as StoryPrompt).opening,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, Object item) async {
    final topic = item is StoryPrompt
        ? 'Story: ${item.title}. ${item.opening}'
        : (item as PracticeTopic).title;
    await context.read<ConversationCubit>().start(topic: topic);
    if (context.mounted) context.push('/conversation');
  }
}

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key});

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  late final Future<List<DailyWord>> _words;

  @override
  void initState() {
    super.initState();
    final store = GetIt.I<LocalStore>();
    _words = GetIt.I<AiGateway>().dailyWords(store).catchError((_) async {
      final fallback = _fallbackWords();
      await store.saveDailyWordSet(_todayKey(), [
        for (final word in fallback)
          {'word': word.word, 'meaning': word.meaning, 'example': word.example},
      ]);
      return fallback;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today’s words')),
      body: FutureBuilder<List<DailyWord>>(
        future: _words,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Loading today’s words…'),
                ],
              ),
            );
          }
          final words = snapshot.data ?? _fallbackWords();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              Text(
                snapshot.hasError
                    ? 'Offline set · 10 useful words'
                    : '10 words for today. Try one in your next conversation.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final entry in words)
                Card(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.word,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(entry.meaning),
                        const SizedBox(height: 7),
                        Text(
                          '“${entry.example}”',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<DailyWord> _fallbackWords() {
    final today = DateTime.now();
    final index =
        today.difference(DateTime(2024, 1, 1)).inDays % vocabularyBank.length;
    return List.generate(
      10,
      (i) => vocabularyBank[(index + i) % vocabularyBank.length],
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
