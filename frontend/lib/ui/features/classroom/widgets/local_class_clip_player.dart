import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';

String formatClipTime(Duration duration) {
  String pad(int value) => value.toString().padLeft(2, '0');
  final minutes = pad(duration.inMinutes.remainder(60));
  final seconds = pad(duration.inSeconds.remainder(60));
  return duration.inHours > 0
      ? '${duration.inHours}:$minutes:$seconds'
      : '$minutes:$seconds';
}

class LocalClassClipPlayer extends StatefulWidget {
  const LocalClassClipPlayer({
    super.key,
    required this.path,
    required this.onDuration,
  });

  final String path;
  final ValueChanged<Duration> onDuration;

  @override
  State<LocalClassClipPlayer> createState() => _LocalClassClipPlayerState();
}

class _LocalClassClipPlayerState extends State<LocalClassClipPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;
  double? _seekPosition;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _failed = true;
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final previous = _controller;
    final controller = VideoPlayerController.file(File(widget.path));
    setState(() {
      _controller = controller;
      _failed = false;
      _seekPosition = null;
    });
    if (previous != null) unawaited(previous.dispose());

    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;
      widget.onDuration(controller.value.duration);
    } on PlatformException {
      if (mounted && _controller == controller) setState(() => _failed = true);
    } on MissingPluginException {
      if (mounted && _controller == controller) setState(() => _failed = true);
    }
  }

  Future<void> _togglePlayback(VideoPlayerController controller) async {
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
    } on PlatformException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _seek(VideoPlayerController controller, double position) async {
    try {
      await controller.seekTo(Duration(milliseconds: position.round()));
    } on PlatformException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted && _controller == controller) {
        setState(() => _seekPosition = null);
      }
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _failed) return _buildUnavailable();

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.hasError) return _buildUnavailable();
        if (!value.isInitialized) {
          return const _VideoSurface(
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                semanticsLabel: 'Opening recorded clip',
              ),
            ),
          );
        }

        final end = value.duration.inMilliseconds.toDouble();
        final position = (_seekPosition ?? value.position.inMilliseconds)
            .clamp(0, end)
            .toDouble();
        final elapsed = Duration(milliseconds: position.round());
        final playing = value.isPlaying;
        final playLabel = value.isCompleted ? 'Replay clip' : 'Play clip';

        return Column(
          spacing: 6,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VideoSurface(
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  if (!playing) const ColoredBox(color: Color(0x40000000)),
                  if (!playing)
                    Center(
                      child: IconButton.filled(
                        tooltip: playLabel,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E6C50),
                          fixedSize: const Size.square(64),
                        ),
                        onPressed: () => _togglePlayback(controller),
                        icon: Icon(
                          value.isCompleted ? Icons.replay : Icons.play_arrow,
                          size: 30,
                        ),
                      ),
                    ),
                  if (value.isBuffering)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        semanticsLabel: 'Buffering',
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: playing ? 'Pause clip' : 'Play recording',
                  onPressed: () => _togglePlayback(controller),
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                ),
                Expanded(
                  child: Semantics(
                    label: 'Clip position',
                    child: Slider(
                      value: position,
                      max: end > 0 ? end : 1,
                      onChanged: end > 0
                          ? (draft) => setState(() => _seekPosition = draft)
                          : null,
                      onChangeEnd: (draft) => _seek(controller, draft),
                      semanticFormatterCallback: (milliseconds) =>
                          formatClipTime(
                            Duration(milliseconds: milliseconds.round()),
                          ),
                    ),
                  ),
                ),
                Text(
                  '${formatClipTime(elapsed)} / ${formatClipTime(value.duration)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnavailable() {
    return _VideoSurface(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 8,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The saved clip could not be opened.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              if (!kIsWeb)
                TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: ColoredBox(
      color: AppColors.ink,
      child: AspectRatio(aspectRatio: 16 / 9, child: child),
    ),
  );
}
