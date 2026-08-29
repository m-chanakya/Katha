import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../exercises/exercise.dart';
import '../services/progress_service.dart';
import '../services/tts_service.dart';

/// Runs one exercise queue end to end, recording each answer against
/// [ProgressService] before advancing. Each [ExerciseType] gets its own
/// small builder below rather than a shared widget -- STRATEGY sec 6
/// treats exercise *types* as the unit of extension, so adding a new
/// generator later means adding one case here, not touching this
/// screen's control flow.
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
  bool _revealed = false;
  String? _selected;
  final Set<String> _matchedLeft = {};
  String? _pendingMatchLeft;

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
      return _SummaryView(total: widget.session.length, correct: _correct, unitTitle: widget.unitTitle);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.unitTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: _index / widget.session.length),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildForType(_current),
      ),
    );
  }

  Widget _buildForType(Exercise ex) {
    switch (ex.type) {
      case ExerciseType.recallFlip:
        return _RecallFlipView(exercise: ex, revealed: _revealed, onFlip: () => setState(() => _revealed = true), onRate: _answerFlip);
      case ExerciseType.mcqRecognition:
      case ExerciseType.audioListen:
        return _McqView(exercise: ex, selected: _selected, onSelect: _answerMcq);
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

  Future<void> _recordAndAdvance(List<String> lexemeIds, Dimension dimension, bool correct) async {
    final progress = context.read<ProgressService>();
    for (final id in lexemeIds) {
      await progress.recordReview(id, dimension, correct ? Rating.good : Rating.again);
    }
    if (correct) _correct++;
    setState(() {
      _index++;
      _revealed = false;
      _selected = null;
      _matchedLeft.clear();
      _pendingMatchLeft = null;
    });
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

class _RecallFlipView extends StatelessWidget {
  final Exercise exercise;
  final bool revealed;
  final VoidCallback onFlip;
  final ValueChanged<bool> onRate;

  const _RecallFlipView({required this.exercise, required this.revealed, required this.onFlip, required this.onRate});

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
                      IconButton(
                        icon: const Icon(Icons.volume_up),
                        onPressed: () => tts.speak(script: null, translit: exercise.audioText ?? exercise.prompt ?? ''),
                      ),
                      if (revealed) ...[
                        const Divider(height: 32),
                        Text(exercise.detail ?? '', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                      ] else
                        Text('Tap to reveal', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

  const _McqView({required this.exercise, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (exercise.audioText != null)
          Center(
            child: IconButton.filled(
              iconSize: 40,
              icon: const Icon(Icons.volume_up),
              onPressed: () => tts.speak(script: exercise.audioText, translit: exercise.audioText!),
            ),
          )
        else
          Text(exercise.prompt ?? '', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ...(exercise.options ?? []).map((option) {
          final isSelected = option == selected;
          final isCorrect = option == exercise.correctAnswer;
          Color? color;
          if (selected != null && isSelected) color = isCorrect ? Colors.green.shade200 : Colors.red.shade200;
          if (selected != null && isCorrect) color = Colors.green.shade200;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black87),
              onPressed: selected == null ? () => onSelect(option) : null,
              child: Text(option),
            ),
          );
        }),
      ],
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
                  style: isPending ? OutlinedButton.styleFrom(backgroundColor: Colors.amber.shade100) : null,
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
  final String unitTitle;

  const _SummaryView({required this.total, required this.correct, required this.unitTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(unitTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 64),
            const SizedBox(height: 16),
            Text('$correct / $total', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Session complete!'),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
