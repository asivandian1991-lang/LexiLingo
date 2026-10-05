import 'dart:convert';

import 'package:http/http.dart' as http;

/// OpenAI-compatible AI gateway with NaraRouter as primary and NVIDIA as fallback.
///
/// API keys must be supplied at runtime (for development via dotenv; for
/// production move these secrets behind a server-side proxy / Firebase Function).
class AiGatewayClient {
  final String naraApiKey;
  final String nvidiaApiKey;
  final String naraBaseUrl;
  final String nvidiaBaseUrl;
  final String naraModel;
  final String nvidiaModel;

  const AiGatewayClient({
    required this.naraApiKey,
    required this.nvidiaApiKey,
    this.naraBaseUrl = 'https://router.bynara.id/v1/chat/completions',
    this.nvidiaBaseUrl =
        'https://integrate.api.nvidia.com/v1/chat/completions',
    this.naraModel = 'auto/bynara',
    this.nvidiaModel = 'openai/gpt-oss-20b',
  });

  bool get isConfigured =>
      naraApiKey.trim().isNotEmpty || nvidiaApiKey.trim().isNotEmpty;

  Future<String> chat({
    required String userMessage,
    String? systemPrompt,
    double temperature = 0.65,
  }) async {
    Object? naraError;

    if (naraApiKey.trim().isNotEmpty) {
      try {
        return await _callOpenAiCompatible(
          endpoint: naraBaseUrl,
          apiKey: naraApiKey,
          model: naraModel,
          userMessage: userMessage,
          systemPrompt: systemPrompt,
          temperature: temperature,
        );
      } catch (e) {
        naraError = e;
      }
    }

    if (nvidiaApiKey.trim().isNotEmpty) {
      try {
        return await _callOpenAiCompatible(
          endpoint: nvidiaBaseUrl,
          apiKey: nvidiaApiKey,
          model: nvidiaModel,
          userMessage: userMessage,
          systemPrompt: systemPrompt,
          temperature: temperature,
        );
      } catch (e) {
        throw StateError(
          'NVIDIA AI request failed: $e'
          '${naraError == null ? '' : ' | NaraRouter failed first: $naraError'}',
        );
      }
    }

    if (naraError != null) {
      throw StateError('NaraRouter AI request failed: $naraError');
    }

    throw StateError('No AI gateway API key is configured.');
  }

  Future<String> _callOpenAiCompatible({
    required String endpoint,
    required String apiKey,
    required String model,
    required String userMessage,
    String? systemPrompt,
    required double temperature,
  }) async {
    final messages = <Map<String, String>>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        {'role': 'system', 'content': systemPrompt.trim()},
      {'role': 'user', 'content': userMessage.trim()},
    ];

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer ${apiKey.trim()}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'temperature': temperature,
            'max_tokens': 700,
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 35));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'HTTP ${response.statusCode}: ${_safeBody(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI response is not a JSON object.');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('AI response contains no choices.');
    }

    final first = choices.first;
    if (first is! Map) {
      throw const FormatException('AI response choice is invalid.');
    }

    final message = first['message'];
    if (message is! Map) {
      throw const FormatException('AI response message is missing.');
    }

    final content = message['content']?.toString().trim() ?? '';
    if (content.isEmpty) {
      throw const FormatException('AI response content is empty.');
    }

    return content;
  }

  String _safeBody(String body) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 300) return normalized;
    return '${normalized.substring(0, 300)}...';
  }
}
