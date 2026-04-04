import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  runApp(ProviderScope(overrides: [storageServiceProvider.overrideWithValue(storage)], child: const CheKarApp()));
}

class CheKarApp extends ConsumerWidget {
  const CheKarApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'CheKar', debugShowCheckedModeBanner: false,
      theme: CheKarTheme.lightTheme, darkTheme: CheKarTheme.darkTheme, themeMode: ThemeMode.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      routerConfig: router,
    );
  }
}
