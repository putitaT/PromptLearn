import 'dart:js_interop';

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import 'replay_api.dart';

class DraftPreview extends StatefulWidget {
  const DraftPreview({super.key, required this.recordingId});

  final String recordingId;

  @override
  State<DraftPreview> createState() => _DraftPreviewState();
}

class _DraftPreviewState extends State<DraftPreview> {
  final _controller = web.AbortController();
  late final _preview = ReplayApi.preview(
    widget.recordingId,
    _controller.signal,
  );
  web.HTMLVideoElement? _video;
  String? _objectUrl;
  bool _playbackFailed = false;

  @override
  void dispose() {
    _controller.abort();
    _video
      ?..onerror = null
      ..pause()
      ..removeAttribute('src')
      ..load();
    if (_objectUrl case final url?) web.URL.revokeObjectURL(url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<web.Blob>(
      future: _preview,
      builder: (context, snapshot) {
        if (snapshot.hasError || _playbackFailed) {
          return const Text('เล่นพรีวิวไม่ได้ ลองปิดแล้วเปิดพรีวิวอีกครั้ง');
        }
        final clip = snapshot.data;
        if (clip == null) {
          return const LinearProgressIndicator(
            semanticsLabel: 'กำลังโหลดคลิปฉบับร่าง',
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: HtmlElementView.fromTagName(
                tagName: 'video',
                onElementCreated: (element) {
                  final url = web.URL.createObjectURL(clip);
                  _objectUrl = url;
                  _video = (element as web.HTMLVideoElement)
                    ..controls = true
                    ..playsInline = true
                    ..setAttribute('aria-label', 'พรีวิวคลิปฉบับร่าง')
                    ..style.width = '100%'
                    ..style.height = '100%'
                    ..style.backgroundColor = '#010e07'
                    ..onerror = ((web.Event _) {
                      if (mounted) setState(() => _playbackFailed = true);
                    }).toJS
                    ..src = url;
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
