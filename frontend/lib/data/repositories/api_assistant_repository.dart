import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/user_role.dart';
import '../../domain/repositories/assistant_repository.dart';

class ApiAssistantRepository implements AssistantRepository {
  const ApiAssistantRepository(this._base, this._client);

  final Uri _base;
  final http.Client _client;

  @override
  Future<String> reply(UserRole role, List<AssistantMessage> messages) async {
    final response = await _client
        .post(
          _base.resolve('/v1/assistant/chat'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'role': role.name,
            'messages': [
              for (final message in messages)
                {
                  'role': message.isUser ? 'user' : 'assistant',
                  'text': message.text,
                },
            ],
          }),
        )
        .timeout(const Duration(seconds: 70));

    if (response.statusCode == 503) throw const AssistantUnavailable();
    if (response.statusCode != 200) {
      throw const FormatException('Invalid PL AI response status.');
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload case {'reply': final String reply}
        when reply.trim().isNotEmpty) {
      return reply.trim();
    }
    throw const FormatException('Missing PL AI reply.');
  }
}
