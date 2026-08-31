import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _AppRoot(),
      ),
    );
  }
}

/// Holds the boot splash until the content bundle and saved progress are
/// both ready, then cross-fades to the home screen.
///
/// Three things here are deliberate:
///
/// * **The load future is created once, in a field, not in `build`.** A
///   `FutureBuilder` handed `ContentService().load()` inline starts a
///   fresh network fetch on every rebuild -- a system theme change was
///   enough -- and re-shows the loading gate with it (ISSUES.md KAT-12).
/// * **The splash has a floor.** On a warm cache the bundle resolves in
///   a few tens of milliseconds, and a gate that appears and vanishes
///   inside 40ms reads as a flicker rather than as a fast start. The
///   floor makes the fastest case look deliberate. It is not a throttle:
///   a slow load is unaffected, because the floor runs alongside it
///   rather than after it.
/// * **One switch, not two.** Content and progress are both gates, but
///   they share a single [AnimatedSwitcher] so the learner sees one
///   fade, not a fade into a second identical wait.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  /// MOTION.md sec 6. Long enough to register as an intentional beat,
  /// short enough that nobody experiences it as waiting.
  static const _splashFloor = Duration(milliseconds: 400);

  late final Future<ContentBundle> _boot = _load();

  Future<ContentBundle> _load() async {
    final loading = ContentService().load();
    final floor = Future<void>.delayed(_splashFloor);
    final bundle = await loading;
    await floor;
    return bundle;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContentBundle>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootFailed(error: snapshot.error);
        }
        final bundle = snapshot.data;
        return Consumer<ProgressService>(
          builder: (context, progress, _) {
            final ready = bundle != null && progress.isLoaded;
            return AnimatedSwitcher(
              duration: AppMotion.of(context).oopiri,
              switchInCurve: AppMotion.of(context).saral,
              child: ready
                  ? Provider<ContentBundle>.value(
                      value: bundle,
                      child: const HomeScreen(),
                    )
                  : const KathaSplash(),
            );
          },
        );
      },
    );
  }
}

/// The boot splash: BRANDING sec 4's app-icon glyph, at display size, on
/// the paper ground.
///
/// It replaces two bare `CircularProgressIndicator`s, which were the
/// app's unbranded first impression and also the reason `pumpAndSettle`
/// can't be used in a widget test -- an indeterminate indicator
/// schedules a new frame forever, so "settled" never arrives (CLAUDE.md,
/// 2026-08-29 follow-up 1). Nothing here animates, so that trap is gone
/// from the boot path.
///
/// The glyph is deliberately the whole design. BRANDING sec 4: క is the
/// first character of కథ, it holds at 40px, and it teaches a letter every
/// time she looks at it. That is the argument for putting it on the app
/// icon, and it costs nothing to make the same argument here.
class KathaSplash extends StatelessWidget {
  const KathaSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        // Suranna, per BRANDING sec 3 -- display sizes only, never below
        // 24px, which is the one rule attached to this face.
        child: Text(
          'క',
          style: GoogleFonts.suranna(
            fontSize: 96,
            height: 1.0,
            color: theme.colorScheme.primary,
          ),
          semanticsLabel: 'Katha',
        ),
      ),
    );
  }
}

/// Shown when the content bundle can't be loaded at all -- neither from
/// the CDN nor from the bundled asset fallback.
///
/// BRANDING sec 8: a control says exactly what happens, and errors say
/// what went wrong and how to fix it, without apologising. The raw error
/// stays on screen, quietly, because this is a pre-release app whose
/// only tester reports bugs to the person who can read them.
class _BootFailed extends StatelessWidget {
  final Object? error;

  const _BootFailed({this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'క',
                  style: GoogleFonts.suranna(
                    fontSize: 56,
                    height: 1.0,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Katha couldn't load its lessons.",
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your connection, then reopen the app.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  '$error',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
