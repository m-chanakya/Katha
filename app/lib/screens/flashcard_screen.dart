import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/word_bank.dart';
import '../models/word.dart';
import '../services/progress_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/flashcard_widget.dart';

/// Runs a review session for one category: due/new words first, "Still
/// learning" vs "Got it" answers drive the Leitner-box scheduling in
/// [ProgressService].
class FlashcardScreen extends StatefulWidget {
  final Category category;

  const FlashcardScreen({super.key, required this.category});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late List<Word> _queue;
  int _index = 0;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    final progress = context.read<ProgressService>();
    final all = WordBank.wordsForCategory(widget.category.id);
    final due = progress.dueWords(all);
    // Study due/new words first, then fall back to the whole deck so a
    // session always has something to do even once everything is fresh.
    _queue = due.isNotEmpty ? due : all;
  }

  void _answer(bool knewIt) {
    final progress = context.read<ProgressService>();
    progress.recordReview(_queue[_index].id, knewIt);
    if (knewIt) _correct++;
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    final ttsService = context.read<TtsService>();

    if (_index >= _queue.length) {
      return _SessionComplete(
        category: widget.category,
        reviewed: _queue.length,
        correct: _correct,
      );
    }

    final word = _queue[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.emoji} ${widget.category.label}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _index / _queue.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: Colors.grey.shade200,
                color: AppColors.peacockTeal,
              ),
              const SizedBox(height: 8),
              Text('${_index + 1} / ${_queue.length}', style: TextStyle(color: Colors.grey.shade600)),
              const Spacer(),
              FlashcardWidget(key: ValueKey(word.id), word: word, ttsService: ttsService),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _answer(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: AppColors.maroon,
                        side: const BorderSide(color: AppColors.maroon),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Still learning'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _answer(true),
                      child: const Text('Got it!'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionComplete extends StatelessWidget {
  final Category category;
  final int reviewed;
  final int correct;

  const _SessionComplete({required this.category, required this.reviewed, required this.correct});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.label)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text('Deck complete!', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                reviewed == 0 ? 'Nothing due right now — come back later.' : 'You got $correct of $reviewed right.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to decks'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
