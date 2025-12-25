import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class TextAudioPlayerScreen extends StatefulWidget {
  final String title;
  final String text;
  const TextAudioPlayerScreen({
    super.key,
    required this.title,
    required this.text,
  });

  @override
  State<TextAudioPlayerScreen> createState() => _TextAudioPlayerScreenState();
}

class _TextAudioPlayerScreenState extends State<TextAudioPlayerScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = false;
  double _speechRate = 0.5;
  int _currentWordIndex = -1;
  late List<String> _words;
  late String _cleanText;
  DateTime _lastHighlightTime = DateTime.now();
  final ScrollController _scrollController = ScrollController();
  List<int> _wordLineMap = [];
  List<double> _lineOffsets = [];
  int _currentLine = -1;

  // Character boundaries for each word in _cleanText
  List<int> _wordStartIndices = [];
  List<int> _wordEndIndices = [];

  @override
  void initState() {
    super.initState();
    _cleanText = _sanitizeText(widget.text);
    _words = _cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    _computeWordBoundaries();
    _initTts();
  }

  @override
  void dispose() {
    _tts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  String _sanitizeText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), ' ') // Strip HTML tags
        .replaceAll(RegExp(r'&nbsp;|\u00A0'), ' ') // Non-breaking spaces
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces → one
        .trim();
  }

  void _computeWordBoundaries() {
    _wordStartIndices.clear();
    _wordEndIndices.clear();
    int charIndex = 0;
    for (var word in _words) {
      _wordStartIndices.add(charIndex);
      charIndex += word.length;
      _wordEndIndices.add(charIndex);
      charIndex += 1; // account for space
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("und"); // auto-detect
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isPlaying = true);
    });

    _tts.setContinueHandler(() {
      if (mounted) setState(() => _isPlaying = true);
    });

    _tts.setPauseHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });

    _tts.setProgressHandler((String text, int start, int end, String word) {
      if (!_isPlaying || !mounted) return;

      int? wordIndex;
      // Try to find word by start offset
      for (int i = 0; i < _wordStartIndices.length; i++) {
        if (start >= _wordStartIndices[i] && start < _wordEndIndices[i]) {
          wordIndex = i;
          break;
        }
      }

      // Fallback: use end offset if start didn't match
      if (wordIndex == null) {
        for (int i = 0; i < _wordEndIndices.length; i++) {
          if (end <= _wordEndIndices[i]) {
            wordIndex = i;
            break;
          }
        }
      }

      if (wordIndex != null) {
        final now = DateTime.now();
        if (now.difference(_lastHighlightTime).inMilliseconds > 120) {
          if (mounted) {
            setState(() {
              _currentWordIndex = wordIndex!;
            });
          }
          _lastHighlightTime = now;
          _scrollToWord(wordIndex!);
        }
      }
    });

    _tts.setCompletionHandler(() {
      if (mounted) _resetPlaybackState();
    });

    _tts.setCancelHandler(() {
      if (mounted) _resetPlaybackState();
    });
  }

  void _resetPlaybackState() {
    setState(() {
      _isPlaying = false;
      _currentWordIndex = -1;
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _tts.pause();
    } else {
      await _tts.speak(_cleanText); // Always full text
    }
  }

  void _computeLineMetrics(BoxConstraints constraints) {
    final double effectiveWidth = constraints.maxWidth - 40.0;
    final TextSpan textSpan = TextSpan(
      text: _cleanText,
      style: const TextStyle(fontSize: 18, height: 1.8, color: Colors.black87),
    );
    final TextPainter painter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: effectiveWidth);
    final List<LineMetrics> lines = painter.computeLineMetrics();

    _lineOffsets = [];
    _wordLineMap = List.filled(_words.length, 0);

    // Compute character start positions of each word
    List<int> wordStarts = [];
    int charPos = 0;
    for (var word in _words) {
      wordStarts.add(charPos);
      charPos += word.length + 1;
    }
    if (_words.isNotEmpty) charPos--; // adjust for last word

    int offset = 0;
    int wordIndex = 0;
    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final double lineY = painter.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
      _lineOffsets.add(lineY);

      // Binary search for line end offset
      int low = offset;
      int high = _cleanText.length;
      while (low < high) {
        final int mid = low + (high - low) ~/ 2;
        final double midY = painter.getOffsetForCaret(TextPosition(offset: mid), Rect.zero).dy;
        if (midY == lineY) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      final int lineEnd = low;

      while (wordIndex < _words.length && wordStarts[wordIndex] < lineEnd) {
        _wordLineMap[wordIndex] = lineIndex;
        wordIndex++;
      }

      offset = lineEnd;
    }
  }

  void _scrollToWord(int wordIndex) {
    if (_wordLineMap.isEmpty || wordIndex >= _wordLineMap.length) return;
    final int lineIndex = _wordLineMap[wordIndex];
    if (lineIndex < 6) return;
    if (lineIndex != _currentLine) {
      _currentLine = lineIndex;
      if (_lineOffsets.isNotEmpty && lineIndex < _lineOffsets.length) {
        final double targetOffset = (_lineOffsets[lineIndex] - 40.0)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _buildHighlightedText() {
    return SelectableText.rich(
      TextSpan(
        children: _words.asMap().entries.map((entry) {
          final index = entry.key;
          final word = entry.value;
          final isActive = index == _currentWordIndex;
          return TextSpan(
            text: "$word ",
            style: TextStyle(
              fontSize: 18,
              height: 1.8,
              color: isActive ? Colors.white : Colors.black87,
              backgroundColor: isActive ? const Color(0xFF6C5CE7) : Colors.transparent,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
      style: const TextStyle(fontSize: 18, color: Colors.black87),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 600),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF6C5CE7),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _isPlaying ? Icons.graphic_eq : Icons.headphones,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isPlaying ? "Reading aloud..." : "Tap play to listen",
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_wordLineMap.isEmpty) {
                    _computeLineMetrics(constraints);
                  }
                });
                return SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildHighlightedText(),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [0.5, 0.75, 1.0, 1.25, 1.5].map((rate) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text("${rate}x"),
                        selected: _speechRate == rate,
                        selectedColor: const Color(0xFF6C5CE7),
                        labelStyle: TextStyle(
                          color: _speechRate == rate ? Colors.white : Colors.black87,
                        ),
                        onSelected: (_) async {
                          setState(() => _speechRate = rate);
                          await _tts.setSpeechRate(rate);
                          if (_isPlaying) {
                            await _tts.stop();
                            await Future.delayed(const Duration(milliseconds: 100));
                            await _tts.speak(_cleanText);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                ZoomIn(
                  duration: const Duration(milliseconds: 400),
                  child: FloatingActionButton.large(
                    backgroundColor: const Color(0xFF6C5CE7),
                    onPressed: _togglePlay,
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}