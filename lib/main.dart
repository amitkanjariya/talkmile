import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:talkmile/app/app.dart';
import 'package:talkmile/core/audio/voice_service.dart';
import 'package:talkmile/core/data/local_store.dart';
import 'package:talkmile/core/network/ai_gateway.dart';
import 'package:talkmile/features/conversation/presentation/conversation_cubit.dart';
import 'package:talkmile/features/settings/presentation/settings_cubit.dart';

final services = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LocalStore();
  await store.open();
  services.registerSingleton<LocalStore>(store);
  services.registerLazySingleton<VoiceService>(VoiceService.new);
  services.registerLazySingleton<AiGateway>(AiGateway.new);
  runApp(
    MultiBlocProvider(
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
    ),
  );
}
