import 'dart:js_interop';

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../../domain/models/user_role.dart';
import '../../core/theme/app_theme.dart';
import 'draft_preview.dart';
import 'replay_api.dart';
import 'replay_player.dart';

class ReplayView extends StatelessWidget {
  const ReplayView({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'คณิตศาสตร์ · ม.1/1',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.mutedText),
              ),
              const SizedBox(height: 8),
              Text(
                'คูณเลขยกกำลังที่มีฐานเดียวกัน',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 24),
              if (role == UserRole.teacher)
                const _TeacherReplay()
              else
                const _StudentReplay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherReplay extends StatefulWidget {
  const _TeacherReplay();

  @override
  State<_TeacherReplay> createState() => _TeacherReplayState();
}

class _TeacherReplayState extends State<_TeacherReplay> {
  web.File? _video;
  String? _recordingId;
  String? _message;
  bool _error = false;
  bool _uploading = false;
  bool _publishing = false;
  bool _published = false;
  bool _showPreview = false;
  double? _progress;

  void _pick() {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.mp4,video/mp4'
      ..setAttribute('aria-label', 'MP4');
    input.onchange = ((web.Event _) {
      final file = input.files?.item(0);
      if (file == null || !mounted) return;
      setState(() {
        _video = file;
        _recordingId = null;
        _published = false;
        _showPreview = false;
        _message = null;
      });
    }).toJS;
    input.click();
  }

  Future<void> _upload() async {
    final video = _video;
    if (video == null) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _message = null;
    });
    try {
      final id = await ReplayApi.upload(video, (progress) {
        if (mounted) setState(() => _progress = progress);
      });
      if (!mounted) return;
      setState(() {
        _recordingId = id;
        _message = 'พร้อมเผยแพร่';
        _error = false;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _publish() async {
    final id = _recordingId;
    if (id == null) return;
    setState(() {
      _publishing = true;
      _message = null;
    });
    try {
      await ReplayApi.publish(id);
      if (!mounted) return;
      setState(() {
        _published = true;
        _showPreview = false;
        _message = 'เผยแพร่แล้ว นักเรียนเปิดดูได้';
        _error = false;
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    setState(() {
      _message = ReplayApiException.messageFor(error);
      _error = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _uploading || _publishing;
    final progress = _progress;
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.header,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('คลิปย้อนหลัง', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _fileRow('คลิป MP4', _video, busy ? null : _pick),
            const SizedBox(height: 20),
            if (_uploading) ...[
              LinearProgressIndicator(value: progress == 1 ? null : progress),
              const SizedBox(height: 8),
              Text(
                progress == 1
                    ? 'กำลังถอดเสียงคลิป'
                    : progress == null
                    ? 'กำลังอัปโหลด'
                    : 'อัปโหลด ${(progress * 100).round()}%',
              ),
              const SizedBox(height: 12),
            ],
            if (_message case final message?)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: _error
                          ? Theme.of(context).colorScheme.error
                          : AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy || _video == null || _recordingId != null
                      ? null
                      : _upload,
                  child: const Text('อัปโหลด'),
                ),
                if (_recordingId != null && !_published)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => _showPreview = !_showPreview),
                    child: Text(
                      _showPreview ? 'ปิดพรีวิว' : 'พรีวิวคลิปฉบับร่าง',
                    ),
                  ),
                FilledButton(
                  onPressed: busy || _recordingId == null || _published
                      ? null
                      : _publish,
                  child: Text(_publishing ? 'กำลังเผยแพร่' : 'เผยแพร่'),
                ),
              ],
            ),
            if (_recordingId case final id? when _showPreview) ...[
              const SizedBox(height: 16),
              DraftPreview(key: ValueKey(id), recordingId: id),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fileRow(String label, web.File? file, VoidCallback? onPressed) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              Text(
                file?.name ?? 'ยังไม่ได้เลือก',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: onPressed, child: Text('เลือกไฟล์ $label')),
      ],
    );
  }
}

class _StudentReplay extends StatefulWidget {
  const _StudentReplay();

  @override
  State<_StudentReplay> createState() => _StudentReplayState();
}

class _StudentReplayState extends State<_StudentReplay> {
  late Future<ReplayJson> _recording = ReplayApi.published();

  void _refresh() => setState(() => _recording = ReplayApi.published());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _recording,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data;
        if (data == null || data['published'] != true) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.hasError
                        ? ReplayApiException.messageFor(snapshot.error)
                        : 'ยังไม่มีคลิปย้อนหลัง',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('โหลดใหม่'),
                  ),
                ],
              ),
            ),
          );
        }
        return ReplayPlayer(key: ValueKey(data['recordingId']), data: data);
      },
    );
  }
}
