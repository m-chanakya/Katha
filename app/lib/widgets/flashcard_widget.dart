import 'dart:math';

import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// A tappable card that flips between the English prompt and the Telugu
/// answer (transliterated, plus an example sentence and pronunciation).
class FlashcardWidget extends StatefulWidget {
  final Word word;
  final TtsService ttsService;

  const FlashcardWidget({super.key, required this.word, required this.ttsService});

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  bool _showingBack = false;

  @override
  void didUpdateWidget(covariant FlashcardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.id != widget.word.id) {
      _controller.value = 0;
      _showingBack = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    setState(() {
      _showingBack = !_showingBack;
      if (_showingBack) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * pi;
          final isBackVisible = angle > pi / 2;
          final displayAngle = isBackVisible ? angle - pi : angle;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(displayAngle),
            child: isBackVisible
                ? _CardBack(word: widget.word, ttsService: widget.ttsService)
                : _CardFront(word: widget.word),
          );
        },
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  final Word word;
  const _CardFront({required this.word});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.english,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Tap to reveal in Telugu',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final Word word;
  final TtsService ttsService;
  const _CardBack({required this.word, required this.ttsService});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              word.telugu,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.peacockTeal),
            ),
            const SizedBox(height: 4),
            Text(word.english, style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
            const SizedBox(height: 12),
            IconButton.filled(
              onPressed: () => ttsService.speak(word.telugu),
              icon: const Icon(Icons.volume_up),
              style: IconButton.styleFrom(backgroundColor: AppColors.turmeric, foregroundColor: Colors.white),
            ),
            if (word.pronunciationTip != null) ...[
              const SizedBox(height: 10),
              Text(
                word.pronunciationTip!,
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            if (word.examples.isNotEmpty) ...[
              const Divider(height: 28),
              for (final example in word.examples) ...[
                Text(example.telugu, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(example.english, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}
