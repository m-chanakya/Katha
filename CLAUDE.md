# Katha — agent resume file

Read this first, every session. It's the front door: what's true right
now, what changed, what's next, and where the *rest* of the context
lives so nobody re-derives it or re-litigates a locked decision.

## Where the rest of the context lives

- **Product/pedagogy strategy** (locked decisions, course architecture,
  FSRS, generators, roadmap phases A-H): `STRATEGY.md` in the **"Katha"
  claude.ai Project** (not this repo — read it via the Projects tool).
  This is the authoritative source for *why* the code looks like this.
- **Visual/verbal identity** (color, type, logo, mascot Uduta): `BRANDING.md`,
  same Project. Subordinate to STRATEGY.md on product decisions.
- **User's persistent memory** (`/areas/katha.md`): who the learner is,
  stage, constraints. Read via the memory tool if you have one.
- `PROJECT_PLAN.md` in this repo is the **Phase 1 plan, superseded** by
  STRATEGY.md's roadmap (STRATEGY §12). Kept for history; don't follow
  its phase numbering.

**If you're a fresh session with none of the above loaded: stop and read
STRATEGY.md before making any product or data-model decision.** This
file tells you *what's built*; STRATEGY.md tells you *what it should
become*.

## Current phase

**STRATEGY §12 Phase A ("Foundations") — in progress.**

Exit criterion: *"Ship a new word to a running app without a build."*
Status: met structurally (content is fetched from a URL at runtime,
not bundled at compile time) — not yet exercised for real because
nothing has been deployed/pushed yet as of this session (see
"Known gap" below).

### Done this session (2026-08-29)

- **Six-entity content model** (`app/lib/models/content.dart`):
  Lexeme, LexemeForm, Concept, ExampleSentence, Scenario, Unit —
  replacing the flat `Word`/`Category` model from Phase 1
  (`app/lib/models/word.dart`, now unused by the app itself, kept only
  because `scripts/migrate_word_bank.py` reads it as the migration source).
- **Migrated the 85 Phase-1 words** into `content/bundle.json` via
  `scripts/migrate_word_bank.py` (idempotent — safe to re-run, it always
  regenerates from `word_bank.dart`, so don't hand-edit `bundle.json`
  and re-run the script in the same change unless you also update the
  script or move to hand-authoring content directly).
- **Content-driven runtime loading**: `ContentService` fetches
  `content/bundle.json` from the GitHub Pages deploy (same artifact as
  the web app — see `.github/workflows/ci.yml`), falls back to the
  bundled asset (`app/assets/content/bundle.json`) on failure/offline.
  This is the "CDN" STRATEGY §1 calls for, cheaply, until it needs to
  be a real CDN.
- **Quality gates** (`scripts/validate_content.py`, STRATEGY §9):
  required fields, duplicate/dangling id references, prerequisite-cycle
  detection, orphan lexemes, plus two intentionally non-blocking
  warnings (see "Content debt").
- **FSRS-lite scheduler** (`app/lib/services/progress_service.dart`):
  per-(lexeme × dimension) card state (STRATEGY §7's key design
  decision), replacing the old single-box-per-word Leitner scheme. It
  is a hand-written SM-2-style scheduler, **not** the real `fsrs`
  package yet — see "Known gap" below for why, and "Next steps" for
  how to close it.
- **Generator framework** (`app/lib/exercises/`): `Exercise` is a plain
  data object (STRATEGY §6: "Exercise is deliberately NOT an entity"),
  produced by `RecallFlipGenerator`, `McqRecognitionGenerator`,
  `AudioListenGenerator`, `MatchPairsGenerator`. Distractor selection
  prefers `Lexeme.confusionLexemeIds` (empty until Phase B authors the
  real confusion graph) and falls back to random same-unit lexemes.
- **Rewrote `home_screen.dart`/`session_screen.dart`** against the new
  model (deleted `flashcard_screen.dart`/`flashcard_widget.dart`).
- **Tests**: `test/progress_service_test.dart` (scheduler correctness),
  `test/content_model_test.dart` (JSON round-trip), updated
  `test/widget_test.dart` (now resilient to randomized exercise
  selection instead of asserting exact card text).
- **CI** (`.github/workflows/ci.yml`): every push runs
  `validate_content.py` + `flutter analyze` + `flutter test`; every push
  to `main`/`master`/`claude/**` also builds the web app and deploys it
  (plus the content bundle) to GitHub Pages. **This is the continuous
  test loop** — after any future push, a fresh clickable build is at
  `https://m-chanakya.github.io/Katha/`.

### Content debt (intentional, tracked as CI warnings not failures)

1. **No register/formality/dialect audit yet.** All 85 migrated lexemes
   have `register: null`, `unaudited: true`. STRATEGY §9 makes this a
   native-speaker review-queue job (Achaarya), not something an agent
   should guess. `validate_content.py` reports the count as a warning
   every run so it can't be silently forgotten, but doesn't block CI on
   it. A real review-queue UI is Phase B ("Creator Studio v1") — until
   then, reviewing is just editing `content/bundle.json` by hand or a
   spreadsheet pass.
2. **Sentences are untokenized.** `ExampleSentence` has a `translit`
   string, not a token list resolved to `Form`s. STRATEGY §9's "token
   resolution" gate can't run for real until sentences are authored
   with tokens — today's migrated sentences predate that. Fine for now
   (Phase A doesn't require it); don't treat the current gate's silence
   here as "sentences are validated."
3. **Transliteration scheme is still the open question from STRATEGY
   §13 Q1** (does it mark retroflexion?). `validate_content.py` flags
   inconsistent mid-word capitalization as a warning rather than
   enforcing a rule, because the rule doesn't exist yet. Lock the
   scheme, then flip that check to an error.

## Known gap: this device link has no network access

Discovered this session: when a Claude session is linked to this
Mac via the desktop app's device bridge, the `device_bash` shell runs
inside a sandboxed Linux VM with **no network egress** (blocked by
allowlist) even though it can read/write the real files under
`~/Work/Katha`. Practically:

- **The agent cannot run `flutter pub get`/`analyze`/`test`/`build`**
  from that shell — no access to pub.dev. All Dart/Flutter changes this
  session were written by hand and validated by *reading*, not by
  running the toolchain. **Run `flutter pub get && flutter analyze &&
  flutter test` yourself before trusting a session's Flutter changes**,
  especially after a session that (like this one) couldn't self-verify.
- **The agent cannot `git push`** from that shell either (github.com is
  blocked too). Changes land as real edits + a local commit; **you
  need to run `git push` yourself** to get them onto GitHub and trigger
  CI. This is also why the `fsrs` pub package isn't wired up yet
  (below) — no way to `pub get` it and read its real API this session.
- If a future session has the same device linked and hits the same
  wall, this isn't a regression to debug — it's the sandbox. The
  cloud-container side of a session (no device linked) *does* have
  normal network access, so an alternative for a push-heavy session is
  giving that session GitHub push credentials directly instead of
  going through the device bridge — worth deciding if this friction
  gets annoying.

## Next steps (in rough order)

1. **You**: `cd app && flutter pub get && flutter analyze && flutter
   test`, then `flutter run -d chrome` to sanity-check the session flow
   by hand, then `git push`.
2. Once pushed, check the Actions tab — first real run of `ci.yml`.
   Fix anything `flutter analyze`/`test` catches that this session
   couldn't see.
3. Swap the FSRS-lite scheduler for the real `fsrs` pub package now that
   `pub get` can actually resolve and you (or a session with network)
   can read its API — the (lexeme × dimension) shape in
   `progress_service.dart` was deliberately built to make this a
   localized swap, not a data-model change.
4. Start the native-speaker register audit (content debt #1) — even a
   pass over `content/bundle.json` in a spreadsheet unblocks flipping
   that gate from warning to error.
5. Phase A's remaining STRATEGY §12 items not done this session: event
   schema (defined, not yet wired to a logger), remaining 2 of the "4
   generators" framing (STRATEGY counts recall flip as already-shipped
   + 3 new in Phase A; this session shipped MCQ, audio-listen, and
   match — that's the 3, but STRATEGY's exact 4th generator target is
   worth rechecking against §6 before Phase C).
6. Don't start Phase B (Creator Studio) or Phase C (Section content)
   content authoring until the register audit and a first real
   `flutter test` pass are done — that's the actual Phase A exit gate,
   not just "code exists."

## Testing loop

- **Local, fast**: `cd app && flutter test` (unit + widget tests) and
  `python3 scripts/validate_content.py content/bundle.json` (content
  gates) — both fast enough to run before every commit.
- **Local, interactive**: `cd app && flutter run -d chrome` for a real
  click-through session.
- **Continuous**: push to a tracked branch → GitHub Actions runs the
  above → on success, deploys the web build + content bundle to
  `https://m-chanakya.github.io/Katha/`. That URL is the standing
  "click through and give feedback" loop this session was set up to
  produce — bookmark it.

## Conventions for future sessions

- Content changes go through `content/bundle.json` (or, once it exists,
  a real authoring tool) + `scripts/validate_content.py`, never by
  hand-editing `app/assets/content/bundle.json` directly (that's a
  build artifact copy, kept in sync by whoever ships a content change —
  currently a manual `cp`, worth scripting once this happens often).
- Model changes go in `app/lib/models/content.dart`. If STRATEGY.md's
  entity list changes, update both this file's doc-comments and this
  section.
- Every new generator: extend `ExerciseGenerator` in
  `app/lib/exercises/generator.dart`, add a case in
  `session_screen.dart`'s `_buildForType`, and check whether
  `buildSessionForUnit` should include it.
- Don't add gamification surfaces beyond streak/XP (already existed
  pre-Phase-A) without checking STRATEGY §2 and §8 — hearts, leagues,
  gems and daily-streak-panic are explicitly rejected there, not just
  unbuilt.
