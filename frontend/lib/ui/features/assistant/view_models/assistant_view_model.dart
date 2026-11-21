import 'package:flutter/foundation.dart';

import '../../../../domain/models/user_role.dart';
import '../../../../domain/repositories/assistant_repository.dart';

class AssistantViewModel extends ChangeNotifier {
  AssistantViewModel({required this.role, required this.repository});

  static const messageLimit = 2000;
  static const _contextLimit = 11;

  final UserRole role;
  final AssistantRepository? repository;
  final _messages = <AssistantMessage>[];

  List<AssistantMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  String? get error => _error;
  bool get canSend => !_isSending && _error == null;

  bool _isSending = false;
  bool _disposed = false;
  String? _error;

  Future<void> send(String input) async {
    final text = input.trim();
    if (text.isEmpty || !canSend) return;
    _messages.add(AssistantMessage(text: text, isUser: true));
    await _requestReply();
  }

  Future<void> retry() async {
    if (_isSending || _error == null) return;
    await _requestReply();
  }

  void editFailedMessage() {
    if (_error == null) return;
    _messages.removeLast();
    _error = null;
    notifyListeners();
  }

  Future<void> _requestReply() async {
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      final assistant = repository;
      if (assistant == null) throw const AssistantUnavailable();
      final start = _messages.length > _contextLimit
          ? _messages.length - _contextLimit
          : 0;
      final reply = await assistant.reply(role, _messages.sublist(start));
      if (_disposed) return;
      _messages.add(AssistantMessage(text: reply, isUser: false));
    } on AssistantUnavailable {
      _error = 'PL AI is unavailable. Check the backend connection.';
    } on Exception {
      _error = 'Could not get a reply. Try again.';
    } finally {
      if (!_disposed) {
        _isSending = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
