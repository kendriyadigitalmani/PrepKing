// lib/screens/courses/contents/audio_player_screen.dart
import 'package:animate_do/animate_do.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

class AudioPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> content;
  const AudioPlayerScreen({super.key, required this.content});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _pulseController;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [AndroidLoudnessEnhancer()],
      ),
    );
    _initAudioSession();
    final String? audioUrl = widget.content['resource_url'];
    if (audioUrl != null && audioUrl.isNotEmpty) {
      _audioPlayer.setUrl(audioUrl).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading audio: $e')),
          );
        }
      });
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _audioPlayer.positionStream,
        _audioPlayer.bufferedPositionStream,
        _audioPlayer.durationStream,
            (position, bufferedPosition, duration) => PositionData(
          position,
          bufferedPosition,
          duration ?? Duration.zero,
        ),
      );

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<bool> _onBackPressed() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Audio"),
        content: const Text(
          "Do you want to leave this screen?\nIs the content completed by you?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Stay"),
          ),
          TextButton(
            onPressed: () async {
              await _recordProgress(completed: true);
              Navigator.pop(context, true);
            },
            child: const Text("Completed"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Leave"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _recordProgress({required bool completed}) async {
    // CALL YOUR API HERE
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.content['title'] ?? 'Audio Lesson';
    final String? audioUrl = widget.content['resource_url'];

    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6C5CE7), Color(0xFF4A43B0)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(  // Added for safety on very small screens
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 28),
                          onPressed: () => GoRouter.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20), // Added small top spacing for balance

                  // Album Art / Visualizer (Reduced size)
                  FadeIn(
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1.05).animate(_pulseController),
                      child: Container(
                        width: 240,  // Reduced from 280
                        height: 240, // Reduced from 280
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.headphones_rounded,
                          size: 96,  // Reduced from 120
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40), // Reduced from 60

                  // Title & Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Course Audio Lesson',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16), // Reduced from 20

                  // Speed Selector
                  PopupMenuButton<double>(
                    initialValue: _playbackSpeed,
                    onSelected: (speed) {
                      setState(() => _playbackSpeed = speed);
                      _audioPlayer.setSpeed(speed);
                    },
                    itemBuilder: (context) => [1, 1.25, 1.5, 2, 3, 4]
                        .map((e) => PopupMenuItem(
                      value: e.toDouble(),
                      child: Text("${e}x"),
                    ))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: Text(
                        "${_playbackSpeed}x",
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28), // Reduced from 40

                  // Seek Bar & Time
                  if (audioUrl != null && audioUrl.isNotEmpty)
                    StreamBuilder<PositionData>(
                      stream: _positionDataStream,
                      builder: (context, snapshot) {
                        final positionData = snapshot.data ??
                            PositionData(Duration.zero, Duration.zero, Duration.zero);
                        final duration = positionData.duration;
                        final position = positionData.position;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white30,
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white.withOpacity(0.2),
                                ),
                                child: Slider(
                                  min: 0.0,
                                  max: duration.inMilliseconds.toDouble(),
                                  value: position.inMilliseconds
                                      .toDouble()
                                      .clamp(0.0, duration.inMilliseconds.toDouble()),
                                  onChanged: (value) {
                                    _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    const Text(
                      "Audio file not available",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),

                  const SizedBox(height: 20),

                  // Volume Control
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_down, color: Colors.white),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: 1,
                            value: _volume,
                            onChanged: (value) {
                              setState(() => _volume = value);
                              _audioPlayer.setVolume(value);
                            },
                          ),
                        ),
                        const Icon(Icons.volume_up, color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28), // Reduced from 40

                  // Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 40,
                        color: Colors.white70,
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 32),
                      StreamBuilder<PlayerState>(
                        stream: _audioPlayer.playerStateStream,
                        builder: (context, snapshot) {
                          final playerState = snapshot.data;
                          final processingState = playerState?.processingState;
                          final playing = playerState?.playing ?? false;
                          if (processingState == ProcessingState.loading ||
                              processingState == ProcessingState.buffering) {
                            return const SizedBox(
                              width: 72,
                              height: 72,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 6),
                            );
                          }
                          return BounceInDown(
                            child: GestureDetector(
                              onTap: () {
                                if (playing) {
                                  _audioPlayer.pause();
                                } else {
                                  _audioPlayer.play();
                                }
                              },
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 44,
                                  color: const Color(0xFF6C5CE7),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 32),
                      IconButton(
                        iconSize: 40,
                        color: Colors.white70,
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 16), // Replaced bottom Spacer()
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}