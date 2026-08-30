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
not bundled at compile time). Verified locally as of 2026-08-29
(`flutter test` 11/11 passing twice in a row, `flutter analyze` clean,
`flutter build web --base-href "/Katha/"` succeeds) -- see "Device
shell: running Flutter yourself" below for how. Still not confirmed via
a real CI run, since as of the last update to this file the commits
verifying this hadn't been pushed yet -- check the Actions tab before
trusting that part.

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

### Follow-up fixes, same day (2026-08-29, later)

Three widget-test bugs found and fixed, in order -- kept here because
the debugging path is more instructive than the diffs:

1. `pumpAndSettle` hung forever: an indeterminate `CircularProgressIndicator`
   (shown while `_AppRoot` loads) reschedules a frame forever, so
   "settled" never becomes true regardless of whether the underlying
   Future resolves. Fixed by polling for a specific expected widget
   instead of waiting for "no more frames."
2. That polling fix was itself flaky: a *fixed* pump count doesn't
   account for real timing variance. Fixed by polling with a generous
   upper bound instead of a guessed constant.
3. Still failed, but only ever on the *second* `testWidgets` in the
   file, never the first, never in isolation. Root cause, found only
   after installing Flutter in the device shell and reproducing it
   directly (see "Device shell" section below): `ContentService.load()`'s
   asset fallback calls `rootBundle.loadString`, a genuinely real
   (non-fake) file read, and real I/O like that does not reliably
   complete under `TestWidgetsFlutterBinding`'s pumping -- confirmed by
   watching a bare `FutureBuilder` around it hang on the second test in
   a file while resolving instantly on the first. Fixed by adding
   `ContentService.debugOverrideBundle`, a test hook that returns a
   preset bundle synchronously, so widget tests never touch real I/O at
   all. This is the actual fix; the first two were real improvements
   but neither was sufficient alone.

Lesson for next time: when a test failure doesn't match the obvious
story (here: "just needs more time to load"), suspect state or I/O
behavior specific to the test *harness*, not just the app code, and
verify by running it rather than iterating on stack traces alone.

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

## Device shell: running Flutter yourself (do this, don't guess)

The `device_bash` shell (when a session is linked to Achaarya's Mac via
the desktop app) runs inside an isolated Linux VM, separate from the
real macOS Flutter install -- it can read/write the real files under
`~/Work/Katha` (mounted), but `flutter`/`dart` are not on its PATH and
never will be just because they're installed on the Mac itself. **Do
not assume you can't self-verify Flutter changes** -- you can, with a
one-time-per-session setup:

```sh
# In the VM's own $HOME (NOT under ~/mnt/Katha -- that's the mounted
# project folder; keep tooling out of it):
cd ~ && git clone --branch stable --depth 1 https://github.com/flutter/flutter.git
export PATH="$HOME/flutter/bin:$PATH"
flutter --version        # bootstraps the Dart SDK, ~1 min, one-time

cd ~/mnt/Katha/app
flutter pub get
flutter analyze
flutter test
flutter build web --base-href "/Katha/"   # optional but catches web-only issues
```

This actually found and fixed two real bugs in one session (2026-08-29)
that three rounds of guessing from pasted terminal output had not.
**Prefer running it yourself over reasoning about what a stack trace
probably means** -- reproduce, bisect, fix, verify, in that order.

Notes:
- **Don't assume network is blocked.** Earlier the same day, this VM's
  network genuinely was blocked by an egress allowlist (github.com,
  pub.dev, storage.googleapis.com all refused). Later in the same
  session, with no action taken to fix it, the exact same hosts were
  reachable and the clone/`pub get` above worked fine. Whatever gates
  this is not under agent control and not worth debugging -- just try
  `curl -sI https://github.com` at the start of a session; if it's
  blocked, fall back to careful hand-written changes and ask the user
  to verify; if it's open, do the setup above and self-verify before
  claiming anything works.
- **`git push` needs credentials this VM doesn't have, independent of
  network reachability.** Even when HTTPS to github.com works fine,
  `git push` fails with "could not read Username" -- there's no stored
  credential helper or token here. Pushing is the user's action from
  their own terminal; committing locally (with `git -c user.name=...
  -c user.email=...` if this VM has no git identity configured, which
  is normal -- don't set it globally) is as far as an agent session
  goes on this path.
- **The Flutter clone lives in the VM's own home, not the mounted
  folder, so don't expect it to survive to a brand-new session** --
  each session's device-linked VM may be freshly provisioned. Check
  `which flutter` (after exporting PATH) before assuming you need to
  re-clone; if it's gone, the recipe above takes about a minute.
- If a future session finds network genuinely and durably blocked, the
  cloud-container side of a session (no device linked) *does* have
  normal network access but no access to this repo's real files --
  giving that kind of session GitHub push credentials directly is the
  alternative worth considering if the device-bridge friction here
  becomes a recurring problem.

## Follow-up fixes, same day (2026-08-30) -- audio + first-pass visual identity

Deployed and clicked through live (`https://m-chanakya.github.io/Katha/`
via the browser device bridge). Two things reported: audio silent, UX
too bare. Both fixed and pushed for review as commit `d5be982`:

- **Audio was silent for two independent reasons, not one.** (1)
  `TtsService._ensureInit()` asked the browser for its voice list
  exactly once, immediately -- web loads voices asynchronously, so this
  always saw `[]` and permanently gave up on Telugu-voice detection,
  even on a Mac that actually has one ("Geeta", te-IN) installed. Now
  polls briefly first. (2) Independent of that: `Exercise.audioText`
  (`Lexeme.ttsText` = script-or-translit) was passed as *both* the
  script and the "no-Telugu-voice fallback" argument at every call
  site, so the fallback was still Telugu script text fed to a
  non-Telugu voice -- silence by design per `TtsService`'s own doc
  comment. Added a real `Exercise.audioTranslit` sourced from
  `Lexeme.translit` and wired it through. **Lesson for future sessions
  chasing a "some devices work, some don't" TTS report: check what text
  is actually reaching the fallback path before assuming it's a voice
  availability problem** -- confirmed by patching
  `speechSynthesis.speak` in the live page via the browser device
  bridge's `javascript_tool` and reading back the utterance text, not
  by reasoning about the code alone.
- **First real pass at BRANDING.md's Phase A visual-identity checklist**
  (color tokens, Anek fonts, dark mode) -- see `app/lib/theme/app_theme.dart`.
  Session/home screens got layout and feedback-color follow-through
  (centered/width-capped session view, `AppSemanticColors` for
  pacha/erra instead of raw `Colors.green/red`). Not done: the
  mascot/illustration system (explicitly Phase D+ per BRANDING sec 9),
  and `TeluguText` isn't wired into any screen yet since native script
  isn't surfaced in the UI at all currently (STRATEGY: transliteration
  first, script "surfaced later"). `google_fonts` fetches Anek at
  runtime from Google's CDN -- fine for real users, but this session's
  device-shell network blocks `fonts.gstatic.com`, so font rendering
  couldn't be visually verified from here (only via the browser device
  bridge, which uses the machine's real network and did work).

## Next steps (in rough order)

1. **You**: `git push` (this VM has network but no push credentials --
   see "Device shell" above). Then check the Actions tab for the first
   real `ci.yml` run against these changes.
2. `flutter run -d chrome` for a real click-through sanity check by
   hand -- automated tests passing doesn't mean the session flow
   *feels* right.
3. Swap the FSRS-lite scheduler for the real `fsrs` pub package -- a
   session with the device-shell Flutter setup above can now actually
   `flutter pub add fsrs` and read its real API instead of guessing.
   The (lexeme × dimension) shape in `progress_service.dart` was
   deliberately built to make this a localized swap, not a data-model
   change.
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
   content authoring until the register audit is done and CI has
   actually gone green on a real push -- that's the actual Phase A
   exit gate, not just "tests pass locally."

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
