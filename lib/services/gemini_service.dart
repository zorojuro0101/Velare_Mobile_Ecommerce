import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSyB7Wr9g8KuGYjEqP622PUOTq6phX64lFEA';

  /// Models to try in order. Gemini 3.1 Flash-Lite is preferred because it
  /// has the highest free-tier daily quota (15 RPM / 500 RPD on the user's
  /// project, vs 20 RPD for the 2.5 Flash family). Sentiment classification
  /// is a cheap task so the lite tier is more than enough.
  /// We fall back to other Lite/Flash variants in case the primary is
  /// temporarily unavailable in some region or rate-limited.
  static const List<String> _models = <String>[
    'gemini-3.1-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
  ];

  static String _endpointFor(String model) =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

  /// Analyzes review sentiment (English, Tagalog, Taglish) using Gemini.
  /// Returns 'positive', 'neutral', 'negative', or null if the query fails.
  ///
  /// On failure it logs the underlying error so callers can see why the
  /// sentiment came back null instead of silently swallowing the error.
  static Future<String?> analyzeSentiment(String reviewText) async {
    if (reviewText.trim().isEmpty) return null;

    final prompt = '''
Analyze the sentiment of the following customer review. The review can be in English, Tagalog, or Taglish (a mixture of Tagalog and English).
Respond strictly in JSON format with a single key 'sentiment' having one of the following values: 'positive', 'neutral', or 'negative'.

Review:
"$reviewText"

Example Output:
{"sentiment": "positive"}
''';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      }
    };
    final body = jsonEncode(requestBody);

    Object? lastError;
    for (final model in _models) {
      try {
        final url = Uri.parse('${_endpointFor(model)}?key=$_apiKey');
        final response = await http
            .post(
              url,
              headers: const {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            lastError = 'No candidates in response: ${response.body}';
            continue;
          }
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List?;
          if (parts == null || parts.isEmpty) {
            lastError = 'No parts in response: ${response.body}';
            continue;
          }
          final textResponse = (parts[0]['text'] as String?)?.trim() ?? '';
          if (textResponse.isEmpty) {
            lastError = 'Empty text in response';
            continue;
          }

          // The response should be JSON; extract sentiment robustly.
          final sentiment = _extractSentiment(textResponse);
          if (sentiment != null) {
            developer.log(
              'Gemini sentiment OK ($model): $sentiment',
              name: 'GeminiService',
            );
            return sentiment;
          }
          lastError = 'Could not parse sentiment from: $textResponse';
        } else {
          // 404 or 400 typically means the model name is wrong/deprecated.
          lastError =
              'HTTP ${response.statusCode} from $model: ${response.body}';
        }
      } catch (e) {
        lastError = e;
      }
    }

    developer.log(
      'Gemini sentiment FAILED. Last error: $lastError',
      name: 'GeminiService',
      level: 1000, // SEVERE
    );
    return null;
  }

  static String? _extractSentiment(String raw) {
    // Try direct JSON parse first
    try {
      final j = jsonDecode(raw);
      if (j is Map && j['sentiment'] is String) {
        final s = (j['sentiment'] as String).toLowerCase().trim();
        if (s == 'positive' || s == 'neutral' || s == 'negative') {
          return s;
        }
      }
    } catch (_) {
      // fall through to regex
    }
    // Fallback: regex-extract a sentiment value if the model returned
    // something like ```json {"sentiment":"positive"} ```
    final match = RegExp(
      r'"sentiment"\s*:\s*"(positive|neutral|negative)"',
      caseSensitive: false,
    ).firstMatch(raw);
    return match?.group(1)?.toLowerCase();
  }
}
