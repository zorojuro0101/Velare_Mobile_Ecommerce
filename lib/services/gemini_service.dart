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

  // ---------------------------------------------------------------------------
  // Voice search keyword extraction
  // ---------------------------------------------------------------------------

  /// Structured result mula sa voice search NLP.
  ///
  /// - [keywords] = product-only search query (e.g. "dress", "yoga pants")
  /// - [color]    = canonical English color name (e.g. "red", "purple") na
  ///   pwedeng i-feed sa color-similarity filter sa product variants.
  ///
  /// Both fields can be null/empty if the model couldn't determine them.
  static Future<VoiceSearchExtraction?> extractSearchKeywords(String transcript) async {
    if (transcript.trim().isEmpty) return null;

    final prompt = '''
You are a search query extractor for a Filipino fashion e-commerce app named Velare.

Task: Convert the user's spoken request into a STRUCTURED search.

Rules:
1. The user may speak in English, Tagalog, or Taglish. Output MUST be in English.
2. Translate any Tagalog clothing/color words to English (e.g. "puti"->"white", "pula"->"red", "berde"->"green", "asul"->"blue", "lila"->"purple", "rosas"->"pink", "kahel"->"orange", "dilaw"->"yellow", "abo"->"gray", "itim"->"black", "kayumanggi"->"brown", "damit"->"clothes", "sapatos"->"shoes", "polo"->"polo shirt", "saya"->"skirt", "blusa"->"blouse").
3. Strip filler words like "hanap mo ako ng", "looking for", "I want", "may meron ba", "please", "po", "can you find".
4. Extract two fields:
   - "keywords": ONLY product-type words (e.g. "dress", "yoga pants", "sapatos"->"shoes", "skirt"). NO colors here. NO sizes.
   - "color": ONE canonical English color name (lowercase) if mentioned, else "".
5. Allowed colors: black, white, gray, red, pink, orange, yellow, green, teal, blue, purple, brown.
6. Output strictly JSON: {"keywords": "<query>", "color": "<color or empty>"}.
7. If the transcript is gibberish or unrelated, output {"keywords": "", "color": ""}.

Transcript:
"$transcript"

Examples:
"hanap mo ako ng dress na kulay black" -> {"keywords": "dress", "color": "black"}
"I'm looking for red yoga pants" -> {"keywords": "yoga pants", "color": "red"}
"sapatos na puti" -> {"keywords": "shoes", "color": "white"}
"meron ba kayong skirts" -> {"keywords": "skirts", "color": ""}
"may itim na blusa" -> {"keywords": "blouse", "color": "black"}
"purple eggplant dress" -> {"keywords": "dress", "color": "purple"}
"ano ulam mamaya" -> {"keywords": "", "color": ""}
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

          final extraction = _extractStructured(textResponse);
          if (extraction != null) {
            developer.log(
              'Gemini voice keywords OK ($model): "$transcript" -> '
              'keywords="${extraction.keywords}", color="${extraction.color}"',
              name: 'GeminiService',
            );
            return extraction;
          }
          lastError = 'Could not parse query from: $textResponse';
        } else {
          lastError =
              'HTTP ${response.statusCode} from $model: ${response.body}';
        }
      } catch (e) {
        lastError = e;
      }
    }

    developer.log(
      'Gemini voice keywords FAILED. Last error: $lastError',
      name: 'GeminiService',
      level: 1000, // SEVERE
    );
    return null;
  }

  static VoiceSearchExtraction? _extractStructured(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is Map) {
        final kw = (j['keywords'] as String?)?.trim() ?? '';
        final color = (j['color'] as String?)?.trim().toLowerCase() ?? '';
        return VoiceSearchExtraction(
          keywords: kw,
          color: color.isEmpty ? null : color,
        );
      }
    } catch (_) {
      // Fallback: regex
    }
    final kwMatch =
        RegExp(r'"keywords"\s*:\s*"([^"]*)"', caseSensitive: false).firstMatch(raw);
    final colorMatch =
        RegExp(r'"color"\s*:\s*"([^"]*)"', caseSensitive: false).firstMatch(raw);
    if (kwMatch == null && colorMatch == null) return null;
    final kw = kwMatch?.group(1)?.trim() ?? '';
    final color = colorMatch?.group(1)?.trim().toLowerCase();
    return VoiceSearchExtraction(
      keywords: kw,
      color: (color == null || color.isEmpty) ? null : color,
    );
  }
}

/// Structured output ng [GeminiService.extractSearchKeywords].
class VoiceSearchExtraction {
  /// Product-type search terms (no color, no filler).
  final String keywords;

  /// Canonical English color name (lowercase), or null kung walang nabanggit.
  final String? color;

  const VoiceSearchExtraction({required this.keywords, this.color});

  /// Convenience: combine keywords + color into a single display string.
  String get displayQuery {
    if (color == null || color!.isEmpty) return keywords;
    if (keywords.isEmpty) return color!;
    return '$color $keywords';
  }

  bool get isEmpty => keywords.isEmpty && (color == null || color!.isEmpty);
  bool get isNotEmpty => !isEmpty;
}
