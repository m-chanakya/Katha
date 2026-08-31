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
- **Design production sequencing** (what art gets made when, the two
  lanes, the style-spec gate): `PRODUCTION.md`, same Project. Subordinate
  to both of the above.
- **Motion, feedback & audio** (the `AppMotion` token set, the card flip,
  earcons for correct/not-yet, how Uduta animates and how the household
  does not): `MOTION.md`, same Project. Subordinate to all three above.
- **Known defects, doc drift and open decisions**: `ISSUES.md`, same
  Project. Read it before starting work, and again before "fixing"
  anything -- the item may already be recorded, already decided, or
  deliberately `won't fix`. Add to it whenever you find something and
  don't fix it in the same pass. Rule of thumb: **this file is what's
  built; `ISSUES.md` is what's wrong.**
- **User's persistent memory** (`/areas/katha.md`): who the learner is,
  stage, constraints. Read via the memory tool if you have one.
- `PROJECT_PLAN.md` in this repo is the **Phase 1 plan, superseded** by
  STRATEGY.md's roadmap (STRATEGY §12). Kept for history; don't follow
  its phase numbering.

**If you're a fresh session with none of the above loaded: stop and read
STRATEGY.md before making any product or data-model decision.** This
file tells you *what's built*; STRATEGY.md tells you *what it should
become*; ISSUES.md tells you where the two currently disagree -- and
that last one matters most when a doc's own status section claims
something is done, because ISSUES.md tracks exactly those claims (see
its "Doc drift" section).

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

## Weekly muggu on the homepage (2026-08-31)

First deliberate step into BRANDING.md sec 7's Phase D engagement
mechanics -- scoped down on purpose after a design discussion: **just
the muggu**, staying local-only storage (no backend), as a programmatic
placeholder motif rather than waiting on real illustration. Ginjalu
(XP rename), marapu ink-fade, leech clinic and Uduta are explicitly
*not* in this pass -- see that conversation if picking those up later,
and re-confirm scope rather than assuming "finish Phase D" was implied.

- `ProgressService` now tracks a `Map<String,int>` of items-reviewed
  per calendar day (`_dailyReviewCounts`, persisted, trimmed to 30
  days), and a fixed `dailyItemGoal = 8` (STRATEGY sec 8's "~8 due
  items" number, not yet the adaptive FSRS-forecast version it
  describes -- that's a real follow-up, not this pass). `weekMuggu()`
  returns the current Monday..Sunday as `MugguDay`s
  (complete/incomplete/today/future).
- `app/lib/widgets/muggu.dart`: `WeeklyMuggu` renders those 7 days as a
  row of small hand-drawn loop motifs (`CustomPainter`, not an
  authentic kolam algorithm -- a stand-in for the real illustrated
  version BRANDING sec 7 wants eventually). Complete days use `pacha`,
  today fills in proportionally to items reviewed so far, future days
  are barely-there placeholders. Swapping in real art later is a
  one-file change.
- Home screen: dropped the bare streak-number chip from the app bar
  (redundant now) and put `WeeklyMuggu` at the top of the unit list
  instead, per the explicit ask to make progress visualizable rather
  than a number.
- Added `ProgressService.weekMuggu()` unit tests (week bounds, today
  vs incomplete vs future, goal-reached -> complete).

Verified: flutter analyze clean, 15/15 tests pass, flutter build web
succeeds. **Not verified visually** -- this session's local web-server
smoke test couldn't reach the device's browser (different network
namespace than the device shell), so the muggu's actual look hasn't
been eyeballed by anyone yet. Worth a real look after this deploys.

## Real FSRS swap (2026-08-30, later)

Replaced the hand-written SM-2-style `CardState` in
`app/lib/services/progress_service.dart` with the real
[`fsrs`](https://pub.dev/packages/fsrs) pub package, now that a session
can `flutter pub add` and inspect its actual API from the device shell.

- `CardState` now wraps an internal `fsrs.Card` (state/stability/
  difficulty/step/due/lastReview) behind the same public shape it had
  before (`stability`, `difficulty`, `dueAt`, `reps`, `lapses`, `isNew`,
  `isDue`, `applyReview(Rating)`) -- no call site outside this file
  changed. `Scheduler.desiredRetention` defaults to 0.9, which is
  exactly STRATEGY sec 7's "target ~90% retention," so it's
  intentionally left unconfigured.
- **Old saved progress migrates automatically.** `CardState.fromJson`
  detects the pre-FSRS JSON shape (no `'card'` key) and rebuilds an
  equivalent `fsrs.Card` from the old flat fields, so upgrading doesn't
  wipe anyone's actual review history out from under them.
- **Real FSRS has learning-step behavior the placeholder didn't**: a
  brand-new card's first "good" rating doesn't jump straight to a
  multi-day interval -- it advances one learning step (10 min by
  default) and only graduates to the day-scale review state after a
  second correct review. This is correct FSRS behavior, not a bug; it
  will make new items feel like they come back sooner than before.
- Updated `progress_service_test.dart`'s assertions to check direction
  and bounds (interval grows, stability positive, easy > good) rather
  than exact numbers, since those now come from FSRS's own externally
  maintained parameters rather than arithmetic this codebase owns. One
  assertion changed on purpose: the placeholder floored stability at a
  hardcoded 1.0 after a lapse; real FSRS's actual floor is 0.001, so a
  badly-lapsed card can legitimately come back due within hours. More
  accurate, not a regression.

Verified: flutter analyze clean, 11/11 tests pass, flutter build web
succeeds. Not yet done: nothing downstream reads `CardState.difficulty`
or the FSRS `state`/`step` fields for UI purposes yet (e.g. surfacing
"learning" vs "review" to the learner) -- STRATEGY's "You" tab (sec 8)
is the natural home for that, and is Phase D+ anyway.

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

## Teaching modules + hints (2026-08-31)

The app could test but not teach. Every exercise type was a quiz, so a
brand-new lexeme's *first ever* appearance in Katha was a four-option MCQ
about a word the learner had never seen. This pass adds the missing half.

**Scope was chosen with the user, not assumed** -- word-intro cards and
grammar/bridge concept cards were picked; a unit "what you'll learn"
screen and a browse/study mode were offered and explicitly *not* taken.
Don't build those on the assumption they were implied.

### The pedagogy tension, and how it's resolved

STRATEGY sec 10 rule 1 says "retrieval, never exposure. Ban 'here are 10
new words, tap next.'" Teaching cards are exposure. The reconciliation is
**placement, not exemption**: `withWordIntros()` inserts a wordIntro
immediately before that same lexeme's first retrieval in the same queue,
so exposure and retrieval arrive as one beat. Two intros are never
adjacent, and `teaching_test.dart` asserts that directly -- if that test
ever fails, Katha has silently become a flashcard app.

Consequences that fall out of the same rule:
- Match-the-following rounds are sorted to the **end** of the graded list.
  They cover five lexemes at once, so an early match round would either
  emit five intro cards back to back or quiz words she'd never met.
- Multi-lexeme exercises introduce nothing; their words get introduced by
  their own single-item exercises earlier in the queue.
- Concept cards are capped at **one per session** (rule 8: "vocabulary can
  be plural; grammar cannot") and marked seen so they don't re-teach.

### New exercise types (`app/lib/exercises/`)

`ExerciseType.wordIntro` and `ExerciseType.conceptTeach`, both
`isTeaching: true` -- they record no review, earn no XP, and don't count
toward the daily item goal. `Exercise` gained teaching fields (script,
pronunciationTip, title/body/bridgeNote/bridgeKind, `examples`) and
`SessionScreen._advanceOnly()` walks past them without touching FSRS.

**Script is always shown on teaching cards** (a deliberate call, not an
oversight vs STRATEGY sec 1's transliteration-first). Nothing is being
scored on a teach card, so there's no answer to leak, and free exposure to
the writing system now makes the Phase F script track a recognition
problem rather than a cold start. Graded exercises still never show script
unless the learner asks for it as a hint.

### Hints (`HintKind`, `Hint`, `_HintBar`)

Audio / script / spelling / meaning, on demand, on every graded exercise.

**Hints are chosen by the generator, never by the UI**, because only the
generator knows which direction it asked its question in. Concretely:
`McqRecognitionGenerator` asking gloss -> pick-the-Telugu offers **no
hints at all**, since audio or script would identify the right button;
the same generator asking Telugu -> pick-the-meaning offers both. Match
rounds offer nothing (every answer is already on screen). If you add a
generator, decide its hints there and add the "hint is never the answer"
case to `teaching_test.dart`.

`HintKind.audio` is **not penalizing** -- the learner has zero ambient
Telugu (STRATEGY sec 1a.1), so audio exposure is the thing we most want to
be free. It's still counted, just not scored.

A correct answer with a penalizing hint is recorded as `Rating.hard`
rather than `Rating.good` (so it comes back sooner, and earns 5 XP not
10). Deliberately a downgrade and **not** a failure: marking it wrong
would make checking feel like punishment and push her back to guessing,
destroying both the signal and the teaching.

`ProgressService` now persists `_hintCounts` per (lexeme × dimension) --
same key shape as the FSRS cards, because a hint is evidence about exactly
what a card schedules. `mostHintedLexemes()` is the seed of STRATEGY sec
7's leech clinic: a word she keeps checking is a word to re-teach, and it
surfaces *sooner* than a lapse count does, because she can be reaching for
the hint every time and still scoring correct. This matters at n=1 --
STRATEGY sec 2a kills p-value and discrimination, but hint counts are
within-learner and survive. **Not yet done:** nothing feeds hint counts
into FSRS difficulty proper; that's the Phase E follow-up the data is
being collected for.

Old saved progress without `hintCounts`/`seenConceptIds` loads fine
(absent keys default to empty) -- covered by a test.

### Content: 12 hand-authored concepts, all unaudited

`content/concepts.json` is new and is the **first hand-authored content in
the repo**. `scripts/migrate_word_bank.py` now merges it into
`bundle.json` and populates `unit.conceptIds`, so re-running the migration
can't wipe it -- lexemes/sentences stay derived from `word_bank.dart`,
concepts stay authored, `bundle.json` stays a pure build artifact.

One or two concepts per legacy unit, each with a Hindi bridge tagged
free/twist/new (STRATEGY sec 4): dative `naaku kaavali`, zero copula,
kinship-carries-age, the `e-` question-word family, `-ndi` politeness,
`-vaaram` days, `noppiga undi`, `undi` vs `untundi`, and others.

**All 12 are `unaudited: true` and need Achaarya's review** -- this is
exactly STRATEGY sec 9's fourth verdict ("nobody says this"), which no
corpus supplies. Look hardest at `c_undi_untundi` (the habitual vs
right-now split may be stated too crisply) and `c_rangu` (whether the bare
adjective vs `<thing> rangu` split is really that tidy). Editing
`content/concepts.json` and re-running the migration is the review loop
until Phase B's real queue exists.

New content gates in `validate_content.py`: a concept with no
`exampleSentenceIds` is a **blocking error**, not a warning, because
`ConceptTeachGenerator` refuses to build a card from one and it would
therefore be silently invisible in the app -- silent content is worse than
absent content. Bad `bridgeKind` values also block; missing bridge notes,
unaudited concepts and concept-less units warn.

Verified: `flutter analyze` clean, **35/35 tests pass** (was 15), content
gates pass with warnings, `flutter build web` succeeds. **Not verified
visually** at time of writing -- the device shell can't reach a browser,
so the teach cards' actual look needs a pass on the deployed build.

## Motion foundations (2026-08-31) -- MOTION.md items 3 and 5

First code from `MOTION.md` (Project doc, see the pointer above). Scoped
to the two items whose files nobody else was in: **item 4, restoring the
card flip, was deliberately not done** -- `session_screen.dart` was being
rewritten by a concurrent session (the teaching-card / hints work) at the
time, and two writers on one uncommitted 873-line file is how you lose
both. Picked up separately; see ISSUES.md KAT-22.

- **`AppMotion` (`app/lib/theme/app_theme.dart`)** -- a `ThemeExtension`
  beside `AppSemanticColors`, holding MOTION.md sec 2's four durations
  (`reppa` 90ms / `adugu` 180ms / `oopiri` 320ms / `nidaanam` 700ms) and
  two curves (`saral` = easeOutCubic everywhere, `sambaram` = elasticOut,
  rationed to the summary and milestones). Telugu-named for the same
  reason the colors are (BRANDING sec 1).
  **Read it via `AppMotion.of(context)`, never off `Theme` directly** --
  `of` returns the collapsed `AppMotion.reduced` when
  `MediaQuery.maybeDisableAnimationsOf` is set, which is the app's whole
  reduce-motion story in one place. Zero new packages.
- **Boot splash (`app/lib/main.dart`)** -- the two bare
  `CircularProgressIndicator` gates are gone, replaced by one `క` in
  Suranna on the paper ground (BRANDING sec 4's icon glyph), cross-fading
  to the home screen at `oopiri`. Content and progress now share a single
  `AnimatedSwitcher` so there's one fade rather than a fade into a second
  identical wait. **This also removes the indeterminate-indicator trap
  from the boot path** -- the thing that made `pumpAndSettle` unusable
  (2026-08-29 follow-up 1); `pumpUntil` in `widget_test.dart` still works
  and was left alone, but its doc comment now overstates the problem
  (ISSUES.md KAT-23).
- **Fixed ISSUES.md KAT-12 in the same pass**: `_AppRoot` was a
  `StatelessWidget` constructing `ContentService().load()` inside
  `build`, so every rebuild started a fresh fetch. The future is now a
  field on a `State`, created once. A 400ms floor runs *alongside* the
  load (not after it), so a warm-cache boot reads as a deliberate beat
  instead of a 40ms flicker; a slow load is unaffected.

Verified on Flutter 3.47.2 in the device shell: `flutter analyze` clean,
**35/35 tests pass** (including both widget tests, which boot through the
new splash), `flutter build web --base-href "/Katha/"` succeeds. Run
against a *copy* at `~/katha-verify` rather than the mounted folder --
`flutter analyze` needs to rewrite `.flutter-plugins-dependencies` and
the mount refuses deletes. **That copy trick is the recipe to reuse**;
it needs no permission prompt and leaves the real tree untouched.

Committed as its own commit touching only those two files, on purpose,
so the concurrent session's uncommitted work stayed uncommitted.

## Next steps (in rough order)

1. **Achaarya: review the 12 drafted concepts** in
   `content/concepts.json` (see above). They are the first content in
   Katha that makes a claim about how Telugu *works* rather than what a
   word means, so a wrong one teaches a wrong rule -- higher stakes than
   the vocabulary audit.
2. Click through the deployed build and look at the teach cards --
   automated tests passing doesn't mean the session flow *feels* right.
   Specifically unverified: whether one concept card plus six intro
   cards makes a first session too long.
3. Feed hint counts into FSRS difficulty. The data is being collected
   now; nothing reads it yet.
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

- **Content has two halves.** Lexemes/sentences/units are DERIVED from
  `app/lib/data/word_bank.dart` and regenerated on every migration run;
  concepts are AUTHORED in `content/concepts.json`. Edit the authored
  file, re-run `scripts/migrate_word_bank.py`, then
  `scripts/validate_content.py`. Never hand-edit `content/bundle.json`
  (a build artifact — the migration overwrites it) and never hand-edit
  `app/assets/content/bundle.json` (a copy of that artifact, kept in
  sync by a manual `cp`, worth scripting once this happens often).
- Model changes go in `app/lib/models/content.dart`. If STRATEGY.md's
  entity list changes, update both this file's doc-comments and this
  section.
- Every new generator: extend `ExerciseGenerator` in
  `app/lib/exercises/generator.dart`, add a case in
  `session_screen.dart`'s `_buildForType`, and check whether
  `buildSessionForUnit` should include it. **Also decide its hints
  there** -- a generator that offers a reveal which identifies its own
  correct option has quietly deleted the exercise, and only the
  generator knows the question's direction. Add the case to
  `teaching_test.dart`'s "hints never reveal the answer" group.
- Don't add gamification surfaces beyond streak/XP (already existed
  pre-Phase-A) without checking STRATEGY §2 and §8 — hearts, leagues,
  gems and daily-streak-panic are explicitly rejected there, not just
  unbuilt.
- **No literal `Duration` or `Curve` in a widget.** Read them from
  `AppMotion.of(context)` (MOTION.md sec 2). A duration written inline is
  a duration that never honours reduce-motion and never gets retuned.
- **Nothing inside a flashcard or exercise item may loop, pulse or
  animate on its own.** BRANDING sec 5 bans illustration on the card
  because the word is the subject; movement has the same failure mode and
  is worse, because the eye tracks it involuntarily. Motion *of* the card
  (flip, enter, leave) is fine. MOTION.md sec 3.
- **Any new sound needs a line in the earcon spec first** (MOTION.md
  sec 4c). The spec doesn't exist yet, which means the answer today is
  "not yet", not "pick one".
