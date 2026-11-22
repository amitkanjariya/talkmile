import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:talkmile/app/app.dart';
import 'package:talkmile/core/audio/voice_service.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/network/ai_gateway.dart';
import 'package:talkmile/core/theme/app_theme.dart';
import 'package:talkmile/features/conversation/presentation/conversation_cubit.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

final services = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Render Flutter's first frame before touching disk. If preferences or SQLite
  // are slow (or unavailable), Android must not leave the user on its launch
  // splash screen indefinitely.
  runApp(const TalkMileBootstrap());
}

class TalkMileBootstrap extends StatefulWidget {
  const TalkMileBootstrap({super.key});

  @override
  State<TalkMileBootstrap> createState() => _TalkMileBootstrapState();
}

class _TalkMileBootstrapState extends State<TalkMileBootstrap> {
  LocalStore? _store;
  Object? _startupError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _startupError = null;
    });
    LocalStore? store;
    try {
      store = LocalStore();
      await store.open();
      if (!services.isRegistered<LocalStore>()) {
        services.registerSingleton<LocalStore>(store);
      }
      if (!services.isRegistered<VoiceService>()) {
        services.registerLazySingleton<VoiceService>(VoiceService.new);
      }
      if (!services.isRegistered<AiGateway>()) {
        services.registerLazySingleton<AiGateway>(AiGateway.new);
      }
      if (!mounted) return;
      setState(() {
        _store = store;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('TalkMile startup failed: $error\n$stackTrace');
      try {
        await store?.close();
      } catch (_) {
        // Keep the original startup error visible.
      }
      if (!mounted) return;
      setState(() {
        _startupError = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store != null) {
      return MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SettingsCubit(store)..load()),
          BlocProvider(
            create: (_) => ConversationCubit(
              voice: services<VoiceService>(),
              gateway: services<AiGateway>(),
              store: store,
            ),
          ),
        ],
        child: const TalkMileApp(),
      );
    }
    return MaterialApp(
      title: 'TalkMile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: _StartupScreen(
        loading: _loading,
        error: _startupError,
        onRetry: _initialize,
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TalkMile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                if (loading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Getting things ready…'),
                ] else ...[
                  Text(
                    'TalkMile couldn’t start. Please try again.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      '$error',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onRetry, child: const Text('Try again')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
