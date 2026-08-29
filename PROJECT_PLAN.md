# Katha — Project Plan

Katha (కథ, "story") is a Telugu learning app for iOS and Web, built to grow
into a Duolingo-style platform with its own gamification engine, characters,
and quirks — starting as a focused vocabulary trainer.

## First user

The person this is being built for right now: a Punjabi speaker learning
Telugu from scratch, with no Telugu script literacy yet. That shapes two
early decisions:

- **No script yet.** Every word is shown as a plain-English transliteration.
  A dedicated script module comes later (Phase 6) once the vocabulary base
  and habit-forming loop exist.
- **Retroflex consonants get called out**, not glossed over — Punjabi
  distinguishes retroflex sounds too (ਟ/ਡ vs ਤ/ਦ), so leaning on that
  instinct is a real teaching shortcut once the script module lands.

## Locked-in product decisions

| Decision | Choice | Why |
|---|---|---|
| Client stack | **Flutter** (iOS, Web, Android-ready) | One codebase, pixel-consistent custom UI across platforms — important for a gamified, illustration-heavy app later. |
| Backend | **None in v1** — all state is on-device | Nothing to build or pay for until multi-device sync or social features are actually needed. |
| Transliteration | **Simple phonetic spelling** (`amma`, `naanna`, `dhanyavaadamulu`) | No diacritics. Doubled vowels (`aa`, `ee`, `oo`) mark long vowels; capitalized `T/D/N/L` are reserved for retroflex consonants where it matters. |
| Pronunciation audio | **TTS now, recordings later** | `Word.audioAsset` is already modeled as optional — a native-speaker recording can replace the synthesized clip for any individual word with no code change. |

## Phased roadmap

**Phase 0 — Repo & app skeleton** ✅
Flutter project scaffolded for iOS/Android/Web, theming, folder structure.

**Phase 1 — Vocabulary flashcard MVP** ✅ *(this push)*
- Word/Category data model, transliteration-first.
- Starter content: **85 words across 9 categories** (greetings, family,
  numbers, colors, food & drink, question words, days of the week, body
  parts, animals), each with an example sentence.
- Flip-card flashcard UI, category deck screen, session-complete summary.
- Pronunciation via device TTS (`te-IN` locale), fed the actual Telugu
  script behind the scenes per word for accuracy — never shown in the UI.
- Local progress: a 5-box Leitner-style spaced-repetition scheduler, daily
  streak, and XP — persisted on-device, no account needed.

**Phase 2 — Polish & real-device parity** (next)
- Run and tune on an actual iPhone (needs a Mac + Xcode — can't be done
  from this sandbox) and in real desktop/mobile browsers.
- Onboarding flow (why transliteration, how flashcards work).
- Settings: TTS voice/speed, review reminders.
- Audio quality: script-backed TTS landed in Phase 1; next step if it's
  still not good enough is real native-speaker recordings for the words
  people hit most.

**Phase 3 — Gamification engine v1**
- Move from "free-standing flashcard decks" to **structured lessons** (a
  handful of new words + a mixed-review round, Duolingo-style).
- Hearts/lives, daily goal, levels, badges.
- First pass at a **mascot/character** and Katha's own visual voice —
  needs a real design session, not just code.

**Phase 4 — Assessment & test formats**
- Multiple choice, listening comprehension, word-matching, fill-in-the-blank.
- Adaptive review mixing old + new material.

**Phase 5 — Content expansion**
- Basic sentence patterns and simple grammar (not just isolated words).
- Colloquial phrases, numbers beyond 10, more categories.
- Dialect notes where Telangana/Coastal Andhra usage differs.

**Phase 6 — Script module**
- Introduce the Telugu alphabet (vowels, consonants, guninthalu).
- Tracing/writing practice; existing flashcards gain a script view
  alongside (not instead of) the transliteration.

**Phase 7 — Backend & accounts**
- Add a backend only once cross-device sync or social/leaderboard features
  are actually wanted. Local progress format is already JSON-shaped to
  make this migration straightforward.

**Phase 8 — Release**
- App Store submission, web hosting, release builds.

## Content model

```
Category { id, label, emoji }
Word {
  id, telugu (transliterated), english, categoryId, partOfSpeech,
  pronunciationTip?, examples: [{ telugu, english }], audioAsset?
}
```

`lib/data/word_bank.dart` holds the v1 content as plain Dart data — no
backend, no build step, easy to extend by hand or generate from a
spreadsheet later if the word list grows large enough to want tooling.

## Open questions to revisit with the user

These are deliberately not decided yet — they need actual vision/taste
input, not just an engineering default:

1. **Mascot & visual identity** — what should Katha's character(s) look
   and feel like? (Phase 3)
2. **Real audio** — whose voice, and how much of the word list gets
   recorded first? (Phase 2/3)
3. **Lesson structure** — strict Duolingo-style skill tree, or a looser
   category-based flow for longer? (Phase 3)
4. **Dialect focus** — Telangana vs Coastal Andhra usage, if/when they
   diverge in the content. (Phase 5)
5. **Android & distribution** — the app is Android-ready structurally;
   worth deciding when (if ever) to actually ship it there.
