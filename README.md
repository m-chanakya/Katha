# Katha

A Telugu vocabulary app for iOS and Web — flashcards, pronunciation, and
example sentences, all in transliterated English (no script yet).

See [PROJECT_PLAN.md](./PROJECT_PLAN.md) for the vision and phased roadmap.

## Running it

The app lives in [`app/`](./app). Requires the
[Flutter SDK](https://docs.flutter.dev/get-started/install) (stable
channel).

```sh
cd app
flutter pub get

# Web
flutter run -d chrome

# iOS (needs a Mac + Xcode + a simulator or device)
flutter run -d ios

# Android
flutter run -d android
```

Run the tests:

```sh
cd app
flutter test
```

## Project structure

```
app/
  lib/
    models/word.dart        # Word + Category data model
    data/word_bank.dart     # v1 vocabulary content (85 words, 9 categories)
    services/
      progress_service.dart # Leitner-box spaced repetition, streaks, XP
      tts_service.dart      # Pronunciation via device text-to-speech
    screens/
      home_screen.dart      # Deck picker
      flashcard_screen.dart # Flip-card review session
    widgets/flashcard_widget.dart
    theme/app_theme.dart
```

No backend, no accounts — all progress is stored on-device for v1.
