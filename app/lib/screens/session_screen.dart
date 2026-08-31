import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../exercises/exercise.dart';
import '../services/progress_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Runs one exercise queue end to end, recording each answer against
/// [ProgressService] before advancing. Each [ExerciseType] gets its own
/// small builder below rather than a shared widget -- STRATEGY sec 6
/// treats exercise *types* as the unit of extension, so adding a new
/// generator later means adding one case here, not touching this
/// screen's control flow.
///
/// Two things this screen owns beyond rendering:
///
/// * **Teaching cards advance without grading.** A [Exercise.isTeaching]
///   card writes no review, earns no XP and doesn't count toward the
///   daily item goal -- see [_advanceOnly].
/// * **Hints are counted per exercise** and passed to
///   [ProgressService.recordReview], which downgrades a hinted correct
///   answer to [Rating.hard]. Only penalizing hints count; replaying the
///   audio is free.
class SessionScreen extends StatefulWidget {
  final List<Exercise> session;
  final String unitTitle;

  const SessionScreen({super.key, required this.session, required this.unitTitle});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  int _index = 0;
  int _correct = 0;
  int _graded = 0;
  int _hintsThisSession = 0;
  bool _revealed = false;
  String? _selected;
  final Set<String> _matchedLeft = {};
  String? _pendingMatchLeft;

  /// Hints opened on the *current* exercise. Cleared on advance.
  final Set<HintKind> _hintsTaken = {};

  Exercise get _current => widget.session[_index];

  @override
  Widget build(BuildContext context) {
    if (widget.session.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.unitTitle)),
        body: const Center(child: Text('Nothing due right now — come back later!')),
      );
    }
    if (_index >= widget.session.length) {
      return _SummaryView(
        total: _graded,
        correct: _correct,
        hints: _hintsThisSession,
        unitTitle: widget.unitTitle,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.unitTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: ClipRRect(
            child: LinearProgressIndicator(value: _index / widget.session.length, minHeight: 4),
          ),
        ),
      ),
      // A single lesson item, centered and width-capped so a wide
      // desktop/web window doesn't leave the card marooned in a sea of
      // ground color -- the flat-list-of-buttons look this replaces was
      // most of what read as "bare" rather than "calm".
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: _buildForType(_current),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForType(Exercise ex) {
    switch (ex.type) {
      case ExerciseType.wordIntro:
        return _WordIntroView(exercise: ex, onContinue: _advanceOnly);
      case ExerciseType.conceptTeach:
        return _ConceptTeachView(exercise: ex, onContinue: _finishConceptCard);
      case ExerciseType.recallFlip:
        return _RecallFlipView(
          exercise: ex,
          revealed: _revealed,
          onFlip: () => setState(() => _revealed = true),
          onRate: _answerFlip,
          hintsTaken: _hintsTaken,
          onHint: _takeHint,
        );
      case ExerciseType.mcqRecognition:
      case ExerciseType.audioListen:
        return _McqView(
          exercise: ex,
          selected: _selected,
          onSelect: _answerMcq,
          hintsTaken: _hintsTaken,
          onHint: _takeHint,
        );
      case ExerciseType.matchPairs:
        return _MatchView(
          exercise: ex,
          matchedLeft: _matchedLeft,
          pendingLeft: _pendingMatchLeft,
          onTapLeft: (left) => setState(() => _pendingMatchLeft = left),
          onTapRight: _answerMatchRight,
        );
    }
  }

  void _takeHint(HintKind kind) {
    setState(() => _hintsTaken.add(kind));
  }

  /// Penalizing hints only -- audio playback is free (see [HintKind.audio]).
  int get _penalizingHintCount => _hintsTaken.where((h) => h.isPenalizing).length;

  void _resetForNext() {
    _index++;
    _revealed = false;
    _selected = null;
    _matchedLeft.clear();
    _pendingMatchLeft = null;
    _hintsTaken.clear();
  }

  /// Advance past a teaching card: nothing scheduled, nothing scored.
  void _advanceOnly() => setState(_resetForNext);

  Future<void> _finishConceptCard() async {
    final conceptId = _current.conceptId;
    if (conceptId != null) {
      await context.read<ProgressService>().markConceptSeen(conceptId);
    }
    if (mounted) setState(_resetForNext);
  }

  Future<void> _recordAndAdvance(List<String> lexemeIds, Dimension dimension, bool correct) async {
    final progress = context.read<ProgressService>();
    final hints = _penalizingHintCount;
    for (final id in lexemeIds) {
      await progress.recordReview(
        id,
        dimension,
        correct ? Rating.good : Rating.again,
        hintsTaken: hints,
      );
    }
    if (correct) _correct++;
    _graded++;
    _hintsThisSession += hints;
    setState(_resetForNext);
  }

  void _answerFlip(bool knewIt) => _recordAndAdvance(_current.lexemeIds, _current.dimension, knewIt);

  void _answerMcq(String choice) {
    if (_selected != null) return; // already answered
    setState(() => _selected = choice);
    final correct = choice == _current.correctAnswer;
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) _recordAndAdvance(_current.lexemeIds, _current.dimension, correct);
    });
  }

  void _answerMatchRight(String rightLexemeId, String rightText) {
    if (_pendingMatchLeft == null) return;
    final pairs = _current.pairs!;
    final leftLexemeId = pairs.firstWhere((p) => p.left == _pendingMatchLeft).lexemeId;
    final isMatch = leftLexemeId == rightLexemeId;
    if (isMatch) {
      setState(() {
        _matchedLeft.add(_pendingMatchLeft!);
        _pendingMatchLeft = null;
      });
      if (_matchedLeft.length == pairs.length) {
        _recordAndAdvance(_current.lexemeIds, _current.dimension, true);
      }
    } else {
      setState(() => _pendingMatchLeft = null);
    }
  }
}

/// A round speaker button shared by the flip and MCQ/audio views, so
/// pronunciation playback looks and behaves the same everywhere it
/// appears.
class _SpeakerButton extends StatefulWidget {
  final VoidCallback onPressed;
  final double size;

  const _SpeakerButton({required this.onPressed, this.size = 40});

  @override
  State<_SpeakerButton> createState() => _SpeakerButtonState();
}

class _SpeakerButtonState extends State<_SpeakerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.9 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: IconButton.filled(
        iconSize: widget.size * 0.5,
        style: IconButton.styleFrom(
          minimumSize: Size(widget.size, widget.size),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        icon: const Icon(Icons.volume_up_rounded),
        onPressed: () {
          setState(() => _pressed = true);
          widget.onPressed();
          Future.delayed(const Duration(milliseconds: 140), () {
            if (mounted) setState(() => _pressed = false);
          });
        },
      ),
    );
  }
}

/// The row of on-demand reveals under a graded exercise.
///
/// Deliberately always visible and never nagging: the learner shouldn't
/// have to fail, or hunt, to find out how a word is spelled. Once taken,
/// a hint stays open for the rest of the item -- re-hiding it would just
/// force a second tap and a second count for the same piece of help.
class _HintBar extends StatelessWidget {
  final List<Hint> hints;
  final Set<HintKind> taken;
  final ValueChanged<HintKind> onHint;
  final VoidCallback? onPlayAudio;

  const _HintBar({required this.hints, required this.taken, required this.onHint, this.onPlayAudio});

  @override
  Widget build(BuildContext context) {
    if (hints.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final revealed = hints.where((h) => h.value != null && taken.contains(h.kind)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: hints.map((hint) {
            final isTaken = taken.contains(hint.kind);
            return ActionChip(
              avatar: Icon(
                switch (hint.kind) {
                  HintKind.audio => Icons.volume_up_rounded,
                  HintKind.script => Icons.translate_rounded,
                  HintKind.translit => Icons.abc_rounded,
                  HintKind.meaning => Icons.lightbulb_outline_rounded,
                },
                size: 18,
              ),
              label: Text(hint.kind.label),
              // Taken hints stay tappable: audio needs replaying, and a
              // second tap on an open reveal is harmless (the count is a
              // set, not a tally).
              onPressed: () {
                onHint(hint.kind);
                if (hint.kind == HintKind.audio) onPlayAudio?.call();
              },
              backgroundColor: isTaken ? theme.colorScheme.primary.withValues(alpha: 0.14) : null,
              side: isTaken ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)) : null,
            );
          }).toList(),
        ),
        if (revealed.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...revealed.map(
            (hint) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${hint.kind.label}:  ', style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    // Set large on purpose. A revealed hint is something
                    // the learner is trying to *read*, and Telugu script
                    // at label size loses its vowel signs and conjuncts
                    // -- which would make the script hint worse than
                    // useless, since it would still cost her the rating.
                    child: Text(
                      hint.value!,
                      style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// First meeting with a word. Script is shown outright here rather than
/// hidden behind a toggle: nothing is being scored, so there is no answer
/// to leak, and free exposure to the writing system now makes the Phase F
/// script track a recognition problem instead of a cold start.
class _WordIntroView extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onContinue;

  const _WordIntroView({required this.exercise, required this.onContinue});

  @override
  State<_WordIntroView> createState() => _WordIntroViewState();
}

class _WordIntroViewState extends State<_WordIntroView> {
  @override
  void initState() {
    super.initState();
    // Say it on arrival. The learner has zero ambient Telugu (STRATEGY
    // sec 1a.1), so the first thing a new word should do is make a sound.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TtsService>().speak(
            script: widget.exercise.audioText,
            translit: widget.exercise.audioTranslit ?? widget.exercise.prompt ?? '',
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final theme = Theme.of(context);
    final tts = context.read<TtsService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TeachBadge(label: 'New word', icon: Icons.auto_awesome_rounded),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(ex.prompt ?? '', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                if (ex.script != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    ex.script!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 14),
                _SpeakerButton(
                  size: 56,
                  onPressed: () => tts.speak(script: ex.audioText, translit: ex.audioTranslit ?? ex.prompt ?? ''),
                ),
                const SizedBox(height: 18),
                Text(ex.detail ?? '', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                if (ex.pronunciationTip != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    ex.pronunciationTip!,
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (ex.examples.isNotEmpty) ...[
                  const Divider(height: 36),
                  ...ex.examples.map((e) => _ExampleLine(example: e)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: widget.onContinue, child: const Text('Got it')),
      ],
    );
  }
}

/// A grammar card: worked examples first, then the rule, then the Hindi
/// bridge behind one tap.
///
/// The order is load-bearing (STRATEGY sec 10 rule 7). Leading with the
/// rule turns a pattern the learner could have spotted herself into a fact
/// she has to take on trust, and the bridge note in particular lands
/// better as confirmation of a hunch than as a preface.
class _ConceptTeachView extends StatefulWidget {
  final Exercise exercise;
  final Future<void> Function() onContinue;

  const _ConceptTeachView({required this.exercise, required this.onContinue});

  @override
  State<_ConceptTeachView> createState() => _ConceptTeachViewState();
}

class _ConceptTeachViewState extends State<_ConceptTeachView> {
  bool _bridgeShown = false;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Reveal the bridge note *and* bring it into view.
  ///
  /// On a short window the note opens below the fold, so without this the
  /// learner taps "Compare with Hindi" and sees nothing change -- found
  /// by clicking through the deployed build, not by any test.
  void _showBridge() {
    setState(() => _bridgeShown = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  /// STRATEGY sec 4's three flavours, as the learner should hear them.
  (String, IconData) _bridgeFraming(String? kind) => switch (kind) {
        'free' => ('You already do this in Hindi', Icons.handshake_rounded),
        'twist' => ('Looks like Hindi — behaves differently', Icons.compare_arrows_rounded),
        'new' => ('No Hindi equivalent', Icons.explore_rounded),
        _ => ('In Hindi', Icons.language_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final theme = Theme.of(context);
    final (bridgeLabel, bridgeIcon) = _bridgeFraming(ex.bridgeKind);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TeachBadge(label: 'How it works', icon: Icons.school_rounded),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ex.title ?? '', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 18),
                // Examples come first, deliberately.
                ...ex.examples.map((e) => _ExampleLine(example: e, alignLeft: true)),
                if (ex.body != null) ...[
                  const SizedBox(height: 8),
                  Text(ex.body!, style: theme.textTheme.bodyLarge),
                ],
                if (ex.bridgeNote != null) ...[
                  const SizedBox(height: 20),
                  if (!_bridgeShown)
                    OutlinedButton.icon(
                      onPressed: _showBridge,
                      icon: Icon(bridgeIcon, size: 18),
                      label: const Text('Compare with Hindi'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(bridgeIcon, size: 18, color: theme.colorScheme.secondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bridgeLabel,
                                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.secondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(ex.bridgeNote!, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () => widget.onContinue(), child: const Text('Got it')),
      ],
    );
  }
}

/// Small pill marking a card as teaching rather than testing, so the
/// learner can tell at a glance that nothing here is being scored.
class _TeachBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _TeachBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One worked example: the Telugu, its script if authored, its meaning.
class _ExampleLine extends StatelessWidget {
  final TeachExample example;
  final bool alignLeft;

  const _ExampleLine({required this.example, this.alignLeft = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = alignLeft ? TextAlign.left : TextAlign.center;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(example.translit, style: theme.textTheme.titleMedium, textAlign: textAlign),
          if (example.script != null)
            Text(
              example.script!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: textAlign,
            ),
          const SizedBox(height: 2),
          Text(
            example.translation,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: textAlign,
          ),
        ],
      ),
    );
  }
}

class _RecallFlipView extends StatelessWidget {
  final Exercise exercise;
  final bool revealed;
  final VoidCallback onFlip;
  final ValueChanged<bool> onRate;
  final Set<HintKind> hintsTaken;
  final ValueChanged<HintKind> onHint;

  const _RecallFlipView({
    required this.exercise,
    required this.revealed,
    required this.onFlip,
    required this.onRate,
    required this.hintsTaken,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: revealed ? null : onFlip,
            child: Card(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(exercise.prompt ?? '', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      _SpeakerButton(
                        onPressed: () => tts.speak(script: exercise.audioText, translit: exercise.audioTranslit ?? exercise.prompt ?? ''),
                      ),
                      if (revealed) ...[
                        const Divider(height: 32),
                        Text(exercise.detail ?? '', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text('Tap to reveal', style: Theme.of(context).textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!revealed)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _HintBar(hints: exercise.hints, taken: hintsTaken, onHint: onHint),
          ),
        if (revealed)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => onRate(false), child: const Text("Didn't know it")),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(onPressed: () => onRate(true), child: const Text('Knew it')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _McqView extends StatelessWidget {
  final Exercise exercise;
  final String? selected;
  final ValueChanged<String> onSelect;
  final Set<HintKind> hintsTaken;
  final ValueChanged<HintKind> onHint;

  const _McqView({
    required this.exercise,
    required this.selected,
    required this.onSelect,
    required this.hintsTaken,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    void play() => tts.speak(script: exercise.audioText, translit: exercise.audioTranslit ?? exercise.audioText ?? '');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // An audioListen item leads with the speaker (the audio *is* the
          // question); a recognition MCQ leads with the written prompt and
          // keeps audio as an optional hint in the bar below.
          if (exercise.type == ExerciseType.audioListen)
            Center(child: _SpeakerButton(size: 72, onPressed: play))
          else
            Text(exercise.prompt ?? '', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          ...(exercise.options ?? []).map((option) {
            final isSelected = option == selected;
            final isCorrect = option == exercise.correctAnswer;

            Widget button = OutlinedButton(
              onPressed: selected == null ? () => onSelect(option) : null,
              child: Text(option),
            );

            if (selected != null && (isSelected || isCorrect)) {
              final color = isCorrect ? semantic.pacha : semantic.erra;
              button = OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  disabledForegroundColor: color,
                  disabledBackgroundColor: color.withValues(alpha: 0.12),
                  side: BorderSide(color: color, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isCorrect ? Icons.check_circle : Icons.cancel, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(option, style: TextStyle(color: color)),
                  ],
                ),
              );
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.only(bottom: 12),
              child: button,
            );
          }),
          // Hidden once answered -- a reveal after the fact isn't help, and
          // counting it would penalize curiosity.
          if (selected == null) ...[
            const SizedBox(height: 8),
            _HintBar(hints: exercise.hints, taken: hintsTaken, onHint: onHint, onPlayAudio: play),
          ],
        ],
      ),
    );
  }
}

class _MatchView extends StatelessWidget {
  final Exercise exercise;
  final Set<String> matchedLeft;
  final String? pendingLeft;
  final ValueChanged<String> onTapLeft;
  final void Function(String rightLexemeId, String rightText) onTapRight;

  const _MatchView({
    required this.exercise,
    required this.matchedLeft,
    required this.pendingLeft,
    required this.onTapLeft,
    required this.onTapRight,
  });

  @override
  Widget build(BuildContext context) {
    final pairs = exercise.pairs!;
    final cta = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: pairs.where((p) => !matchedLeft.contains(p.left)).map((p) {
              final isPending = p.left == pendingLeft;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton(
                  style: isPending
                      ? OutlinedButton.styleFrom(
                          backgroundColor: cta.withValues(alpha: 0.14),
                          side: BorderSide(color: cta, width: 1.5),
                        )
                      : null,
                  onPressed: () => onTapLeft(p.left),
                  child: Text(p.left),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: (List.of(pairs)..sort((a, b) => a.right.hashCode.compareTo(b.right.hashCode)))
                .where((p) => !matchedLeft.contains(p.left))
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        onPressed: () => onTapRight(p.lexemeId, p.right),
                        child: Text(p.right),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SummaryView extends StatelessWidget {
  final int total;
  final int correct;
  final int hints;
  final String unitTitle;

  const _SummaryView({required this.total, required this.correct, required this.hints, required this.unitTitle});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : correct / total;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    return Scaffold(
      appBar: AppBar(title: Text(unitTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(scale: value, child: child),
                  child: Icon(Icons.celebration, size: 64, color: pct >= 0.8 ? semantic.pacha : Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text('$correct / $total', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('Session complete!'),
                if (hints > 0) ...[
                  const SizedBox(height: 8),
                  // Stated plainly, without a scolding tone: checking is a
                  // legitimate move, and the number is here because it's
                  // useful to her, not because it's a demerit.
                  Text(
                    hints == 1 ? 'You checked 1 hint along the way.' : 'You checked $hints hints along the way.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
