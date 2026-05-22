import 'dart:math' as math;
import 'dart:ui' show Color;

/// Helper para sa fuzzy color matching ng product variants.
///
/// Yung problema: sellers gumagamit ng creative names (e.g. "Eggplant",
/// "Lipstick", "Mulberry Wood", "Cloud Burst"). Pero may `hex_code` naman ang
/// bawat variant — kaya pwede natin gamitin yung **actual color similarity**
/// kahit anong tawag.
///
/// Approach: convert hex -> Lab color space, then compute Euclidean distance
/// (CIE76) against a fixed palette ng canonical English color names. Kapag
/// malapit yung distance (under threshold), naka-match yung variant sa
/// canonical name.
class ColorMatcher {
  ColorMatcher._();

  /// Maximum Lab distance na considered "matching". Lab distances:
  ///   0–10  : nearly indistinguishable
  ///   10–25 : visibly different but in same family
  ///   25–50 : different family
  ///   >50   : very different
  ///
  /// We pick 35 to be permissive (matches loose color families like "purple"
  /// covering plum, eggplant, lavender, magenta, etc.) without bleeding into
  /// neighbouring colors.
  static const double matchThreshold = 35.0;

  /// Canonical color palette. Bawat entry ay may primary English name (key)
  /// at list ng aliases at hex anchors. Pwede kang magdagdag ng more anchors
  /// para sa color na may multiple "shades" (e.g. multiple reds).
  static final Map<String, _ColorEntry> _palette = {
    'black': _ColorEntry(
      aliases: ['itim', 'jet', 'onyx', 'noir', 'midnight', 'cod gray', 'mine shaft'],
      hexAnchors: ['#000000', '#1a1a1a', '#2d2d2d', '#131013'],
    ),
    'white': _ColorEntry(
      aliases: ['puti', 'ivory', 'cream', 'pearl', 'snow', 'off white'],
      hexAnchors: ['#FFFFFF', '#FFFFF0', '#FFFDD0', '#F5F5F5'],
    ),
    'gray': _ColorEntry(
      aliases: ['grey', 'kulay abo', 'silver', 'charcoal', 'slate', 'shark', 'thunder'],
      hexAnchors: ['#808080', '#36454F', '#737373', '#929292'],
    ),
    'red': _ColorEntry(
      aliases: ['pula', 'crimson', 'scarlet', 'cherry', 'ruby', 'lipstick', 'rose'],
      hexAnchors: ['#FF0000', '#DC143C', '#B22222', '#bd0263'],
    ),
    'pink': _ColorEntry(
      aliases: ['rosas', 'kulay rosas', 'fuchsia', 'magenta', 'salmon', 'blush', 'carnation'],
      hexAnchors: ['#FFC0CB', '#FF1493', '#FF69B4', '#fda3be', '#fdaf7d'],
    ),
    'orange': _ColorEntry(
      aliases: ['kahel', 'tangerine', 'coral', 'peach', 'amber', 'terracotta'],
      hexAnchors: ['#FFA500', '#FF7F50', '#FF8C00', '#b03d20'],
    ),
    'yellow': _ColorEntry(
      aliases: ['dilaw', 'gold', 'mustard', 'lemon', 'sunshine', 'canary'],
      hexAnchors: ['#FFFF00', '#FFD700', '#F0E68C', '#FFA500'],
    ),
    'green': _ColorEntry(
      aliases: ['berde', 'kulay berde', 'olive', 'sage', 'forest', 'mint', 'jade', 'pine', 'observatory', 'de york', 'orinoco'],
      hexAnchors: ['#008000', '#228B22', '#9DC183', '#86c489', '#05875f', '#148180', '#eafac9'],
    ),
    'teal': _ColorEntry(
      aliases: ['turquoise', 'cyan', 'aqua', 'petrol', 'anakiwa'],
      hexAnchors: ['#008080', '#00CED1', '#005F6A', '#87f6fb'],
    ),
    'blue': _ColorEntry(
      aliases: ['asul', 'kulay asul', 'navy', 'royal', 'sky', 'azure', 'cobalt', 'steel blue', 'cloud burst', 'midnight', 'baltic sea'],
      hexAnchors: ['#0000FF', '#000080', '#4169E1', '#017eb8', '#23395d', '#001d40', '#201f23'],
    ),
    'purple': _ColorEntry(
      aliases: ['lila', 'kulay lila', 'violet', 'lavender', 'plum', 'eggplant', 'mauve', 'amethyst', 'orchid', 'disco', 'mulberry'],
      hexAnchors: ['#800080', '#9370DB', '#6f576d', '#841a5c', '#6709ab', '#500327'],
    ),
    'brown': _ColorEntry(
      aliases: ['kayumanggi', 'tan', 'beige', 'khaki', 'chocolate', 'mocha', 'chestnut', 'coffee', 'sand', 'desert', 'brandy', 'masala', 'red robin'],
      hexAnchors: ['#A52A2A', '#8B4513', '#D2691E', '#c26e56', '#7d685f', '#a86d25', '#dfc39e', '#3c3233', '#804324'],
    ),
  };

  /// Lookup canonical color name from a free-form input string.
  ///
  /// Tinatanggap nito yung English names ("red"), Tagalog ("pula"), at common
  /// aliases ("crimson"). Returns `null` kung walang match.
  static String? canonicalColorFromName(String? input) {
    if (input == null) return null;
    final normalized = input.toLowerCase().trim();
    if (normalized.isEmpty) return null;

    // Direct key
    if (_palette.containsKey(normalized)) return normalized;

    // Search aliases (whole-word matching)
    for (final entry in _palette.entries) {
      if (entry.value.aliases.contains(normalized)) {
        return entry.key;
      }
      // Also check if normalized contains an alias as a word
      for (final alias in entry.value.aliases) {
        if (_containsWord(normalized, alias)) return entry.key;
      }
      if (_containsWord(normalized, entry.key)) return entry.key;
    }

    return null;
  }

  /// Check if a hex color is a member of a canonical color group.
  ///
  /// Uses CIE76 distance in Lab color space. Mas accurate ito kaysa sa direct
  /// RGB Euclidean distance kasi hindi pareho yung perceived difference between
  /// adjacent RGB shades.
  static bool hexMatchesColor(String? hex, String canonicalName) {
    if (hex == null) return false;
    final lab = _hexToLab(hex);
    if (lab == null) return false;

    final entry = _palette[canonicalName.toLowerCase()];
    if (entry == null) return false;

    for (final anchor in entry.hexAnchors) {
      final anchorLab = _hexToLab(anchor);
      if (anchorLab == null) continue;
      final dist = _labDistance(lab, anchorLab);
      if (dist <= matchThreshold) return true;
    }
    return false;
  }

  /// Find the closest canonical color for a given hex (kahit walang
  /// requirement na specific). Useful for tagging.
  static String? closestCanonicalColor(String? hex) {
    if (hex == null) return null;
    final lab = _hexToLab(hex);
    if (lab == null) return null;

    String? best;
    double bestDist = double.infinity;
    for (final entry in _palette.entries) {
      for (final anchor in entry.value.hexAnchors) {
        final anchorLab = _hexToLab(anchor);
        if (anchorLab == null) continue;
        final dist = _labDistance(lab, anchorLab);
        if (dist < bestDist) {
          bestDist = dist;
          best = entry.key;
        }
      }
    }
    // Only return if reasonably close
    return bestDist <= matchThreshold ? best : null;
  }

  /// All known canonical color names. Useful for UI / debugging.
  static List<String> get canonicalNames => _palette.keys.toList();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------
  static bool _containsWord(String text, String word) {
    final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b');
    return pattern.hasMatch(text);
  }

  /// Parse a hex string (#RRGGBB or #RGB) into Color, then convert to Lab.
  static List<double>? _hexToLab(String hex) {
    final color = _parseHex(hex);
    if (color == null) return null;
    return _rgbToLab(color.red, color.green, color.blue);
  }

  static Color? _parseHex(String hex) {
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) {
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length != 6) return null;
    final value = int.tryParse(s, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  /// sRGB (0..255) -> CIE Lab (L*: 0..100, a/b approx -128..127).
  static List<double> _rgbToLab(int r, int g, int b) {
    // sRGB -> linear RGB
    double srgbToLinear(int v) {
      final c = v / 255.0;
      return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }
    final lr = srgbToLinear(r);
    final lg = srgbToLinear(g);
    final lb = srgbToLinear(b);

    // linear RGB -> XYZ (D65 illuminant)
    final x = lr * 0.4124564 + lg * 0.3575761 + lb * 0.1804375;
    final y = lr * 0.2126729 + lg * 0.7151522 + lb * 0.0721750;
    final z = lr * 0.0193339 + lg * 0.1191920 + lb * 0.9503041;

    // XYZ -> Lab (D65 reference white)
    const xn = 0.95047;
    const yn = 1.00000;
    const zn = 1.08883;
    double f(double t) {
      const delta = 6.0 / 29.0;
      return t > delta * delta * delta
          ? math.pow(t, 1 / 3).toDouble()
          : t / (3 * delta * delta) + 4.0 / 29.0;
    }
    final fx = f(x / xn);
    final fy = f(y / yn);
    final fz = f(z / zn);
    final l = 116 * fy - 16;
    final a = 500 * (fx - fy);
    final bLab = 200 * (fy - fz);
    return [l, a, bLab];
  }

  /// CIE76 Lab Euclidean distance.
  static double _labDistance(List<double> a, List<double> b) {
    final dl = a[0] - b[0];
    final da = a[1] - b[1];
    final db = a[2] - b[2];
    return math.sqrt(dl * dl + da * da + db * db);
  }
}

class _ColorEntry {
  final List<String> aliases;
  final List<String> hexAnchors;
  _ColorEntry({required this.aliases, required this.hexAnchors});
}
