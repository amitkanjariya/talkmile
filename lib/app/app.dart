import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/features/companion/presentation/companion_page.dart';
import 'package:talkmile/features/conversation/presentation/conversation_page.dart';
import 'package:talkmile/features/home/presentation/home_page.dart';
import 'package:talkmile/features/home/presentation/practice_library_page.dart';
import 'package:talkmile/features/onboarding/presentation/onboarding_page.dart';
import 'package:talkmile/features/progress/presentation/progress_page.dart';
import 'package:talkmile/features/settings/presentation/settings_page.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (_, state) {
    if (!GetIt.I<LocalStore>().onboarded &&
        state.matchedLocation != '/welcome') {
      return '/welcome';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomePage()),
    GoRoute(path: '/welcome', builder: (_, _) => const OnboardingPage()),
    GoRoute(path: '/companion', builder: (_, _) => const CompanionPage()),
    GoRoute(path: '/conversation', builder: (_, _) => const ConversationPage()),
    GoRoute(path: '/progress', builder: (_, _) => const ProgressPage()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    GoRoute(
      path: '/topics',
      builder: (_, _) => const PracticeLibraryPage(stories: false),
    ),
    GoRoute(
      path: '/stories',
      builder: (_, _) => const PracticeLibraryPage(stories: true),
    ),
    GoRoute(path: '/vocabulary', builder: (_, _) => const VocabularyPage()),
  ],
);

class TalkMileApp extends StatelessWidget {
  const TalkMileApp({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) => MaterialApp.router(
          title: 'TalkMile',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: switch (settings.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          routerConfig: router,
        ),
      );
}
