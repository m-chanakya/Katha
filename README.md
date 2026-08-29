# Katha

A Telugu learning app (Flutter, iOS/Web/Android). See
**[`CLAUDE.md`](./CLAUDE.md)** for current status and what's next —
that's the resume point for any session, human or agent. The product
and pedagogy strategy lives in `STRATEGY.md` in the Katha claude.ai
Project, not in this repo.

## Running it

```sh
cd app
flutter pub get

flutter run -d chrome   # Web
flutter run -d ios      # needs a Mac + Xcode
flutter run -d android
```

## Testing

```sh
cd app && flutter test                                  # unit + widget tests
python3 scripts/validate_content.py content/bundle.json # content quality gates
```

Every push also runs both in CI (`.github/workflows/ci.yml`) and, on a
tracked branch, deploys a fresh web build to
**https://m-chanakya.github.io/Katha/** — the standing click-through
build for feedback.

## Project structure

```
content/bundle.json         # source of truth: lexemes/sentences/units (6-entity model)
scripts/
  migrate_word_bank.py      # one-time Phase 1 -> content model migration
  validate_content.py       # quality gates, run in CI
app/
  assets/content/bundle.json  # bundled fallback copy of content/bundle.json
  lib/
    models/content.dart       # Lexeme/Form/Concept/Sentence/Scenario/Unit
    services/
      content_service.dart    # fetch-with-fallback content loader
      progress_service.dart   # per-(lexeme x dimension) spaced-repetition state
      tts_service.dart        # pronunciation via device text-to-speech
    exercises/                # exercise generator framework (STRATEGY sec 6)
    screens/
      home_screen.dart        # unit picker
      session_screen.dart     # runs a review session
    theme/app_theme.dart
  test/                       # flutter test suite
```

No backend, no accounts — progress stays on-device (STRATEGY sec 1).
