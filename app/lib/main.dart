import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/progress_service.dart';
import 'services/tts_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const KathaApp());
}

class KathaApp extends StatelessWidget {
  const KathaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProgressService()..load()),
        Provider(create: (_) => TtsService()),
      ],
      child: MaterialApp(
        title: 'Katha',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _AppRoot(),
      ),
    );
  }
}

/// Waits for saved progress to load before showing the home screen, so
/// the deck cards never flash "0 due" before real data arrives.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressService>(
      builder: (context, progress, _) {
        if (!progress.isLoaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return const HomeScreen();
      },
    );
  }
}
