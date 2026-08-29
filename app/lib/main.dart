import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/content.dart';
import 'screens/home_screen.dart';
import 'services/content_service.dart';
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

/// Loads the content bundle (network CDN with bundled-asset fallback --
/// see ContentService) and waits for saved progress, so the unit list
/// never flashes empty/zero before real data arrives.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContentBundle>(
      future: ContentService().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load content: ${snapshot.error}'),
              ),
            ),
          );
        }
        return Provider<ContentBundle>.value(
          value: snapshot.data!,
          child: Consumer<ProgressService>(
            builder: (context, progress, _) {
              if (!progress.isLoaded) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return const HomeScreen();
            },
          ),
        );
      },
    );
  }
}
