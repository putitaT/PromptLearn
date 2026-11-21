import 'dart:js_interop';

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../core/theme/app_theme.dart';
import 'replay_api.dart';

class ReplayPlayer extends StatefulWidget {
  const ReplayPlayer({super.key, required this.data});

  final ReplayJson data;

  @override
  State<ReplayPlayer> createState() => _ReplayPlayerState();
}

class _ReplayPlayerState extends State<ReplayPlayer> {
  late final List<ReplayJson> _cues =
      (widget.data['transcript'] as List<dynamic>).cast<ReplayJson>();
  web.HTMLVideoElement? _video;
  int? _pendingSeek;
  int? _activeCue;
  bool _videoError = false;

  void _attachVideo(Object element) {
    final video = element as web.HTMLVideoElement;
    _video = video
      ..controls = true
      ..playsInline = true
      ..preload = 'metadata'
      ..setAttribute('aria-label', 'คลิปเรียนย้อนหลัง')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#010e07';
    video.onloadedmetadata = ((web.Event _) {
      if (_pendingSeek case final time?) _seek(time);
    }).toJS;
    video.ontimeupdate = ((web.Event _) {
      if (!mounted) return;
      final time = video.currentTime * 1000;
      final active = _cues.lastIndexWhere(
        (cue) =>
            (cue['startMs'] as int) <= time && time < (cue['endMs'] as int),
      );
      if (active != _activeCue) setState(() => _activeCue = active);
    }).toJS;
    video.onerror = ((web.Event _) {
      if (mounted) setState(() => _videoError = true);
    }).toJS;
    video.src = widget.data['videoUrl'] as String;
  }

  void _seek(int time) {
    final video = _video;
    if (video == null || video.readyState == 0) {
      _pendingSeek = time;
      return;
    }
    _pendingSeek = null;
    video.currentTime = time / 1000;
  }

  @override
  void dispose() {
    _video
      ?..onloadedmetadata = null
      ..ontimeupdate = null
      ..onerror = null
      ..pause()
      ..removeAttribute('src')
      ..load();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: HtmlElementView.fromTagName(
            tagName: 'video',
            onElementCreated: _attachVideo,
          ),
        ),
        if (_videoError)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('เล่นคลิปไม่ได้ ลองเปิดหน้าคลิปย้อนหลังใหม่'),
          ),
      ],
    );
    final transcript = Card(
      margin: EdgeInsets.zero,
      color: AppColors.header,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Transcript', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (index, cue) in _cues.indexed)
              ListTile(
                selected: index == _activeCue,
                selectedTileColor: AppColors.notificationBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: Text(_timestamp(cue['startMs'] as int)),
                title: Text(cue['text'] as String),
                onTap: _videoError ? null : () => _seek(cue['startMs'] as int),
              ),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [video, const SizedBox(height: 16), transcript],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: video),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: transcript),
          ],
        );
      },
    );
  }
}

String _timestamp(int millis) {
  final seconds = millis ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
