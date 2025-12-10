// lib/screens/course/contents/video_content_screen.dart
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoContentScreen extends StatefulWidget {
  final Map<String, dynamic> content;
  const VideoContentScreen({super.key, required this.content});

  @override
  State<VideoContentScreen> createState() => _VideoContentScreenState();
}

class _VideoContentScreenState extends State<VideoContentScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final url = widget.content['video_url']?.toString() ?? widget.content['url']?.toString() ?? '';
    final videoId = YoutubePlayer.convertUrlToId(url) ?? '';

    _controller = YoutubePlayerController(
      initialVideoId: videoId.isNotEmpty ? videoId : 'dQw4w9WgXcQ', // fallback
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desc = widget.content['description']?.toString() ?? '';

    return Column(
      children: [
        YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressColors: const ProgressBarColors(
            playedColor: Color(0xFF6C5CE7),
            handleColor: Colors.purple,
          ),
        ),
        if (desc.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(desc, style: const TextStyle(fontSize: 16, height: 1.6)),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}