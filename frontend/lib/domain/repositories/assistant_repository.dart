import '../models/user_role.dart';

class AssistantMessage {
  const AssistantMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

abstract interface class AssistantRepository {
  Future<String> reply(UserRole role, List<AssistantMessage> messages);
}

class AssistantUnavailable implements Exception {
  const AssistantUnavailable();
}
