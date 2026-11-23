import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of image + title resolution from external sources.
class ImageResolveResult {
  final String imageUrl;
  final String correctedTitle;

  const ImageResolveResult({
    required this.imageUrl,
    required this.correctedTitle,
  });
}

/// Finds a real PHOTO for a place from free sources (Wikipedia, Wikimedia
/// Commons), falling back to a LoremFlickr placeholder.
///
/// Wikipedia's "main image" is often not a photo of the place at all - for
/// businesses and organisations it is usually a logo, and for towns and
/// districts it is often a map, flag or coat of arms. So every candidate is
/// checked before it is used:
///  * the article must actually be about the place (title similarity),
///  * the file must be a JPEG (logos, flags, maps and diagrams are almost
///    always SVG/PNG),
///  * its file name must not look like a graphic (logo, map, flag, ...),
///  * it must be big enough and a sensible shape.
///
/// Resolution chain:
///  1. The Wikipedia article's main image, if it passes the checks.
///  2. Another photo from the same article that passes the checks.
///  3. A Wikimedia Commons photo whose file name matches the place.
///  4. LoremFlickr placeholder (last resort).
class ImageResolverConfig {
  ImageResolverConfig._();

  static const _headers = {
    'User-Agent': 'TrekApp/1.0 (Flutter; travel itinerary generator)',
  };

  /// HTTP client. Tests replace this with a mock client.
  static http.Client client = http.Client();

  /// File-name words that mean "graphic, not a photograph".
  static const Set<String> _graphicWords = {
    'logo', 'logos', 'wordmark', 'icon', 'icons', 'pictogram', 'symbol',
    'emblem', 'seal', 'crest', 'badge', 'arms', 'flag', 'flags', 'banner',
    'map', 'maps', 'locator', 'location', 'plan', 'layout', 'blueprint',
    'route', 'diagram', 'chart', 'graph', 'timeline', 'infographic',
    'sketch', 'drawing', 'illustration', 'cartoon', 'vector', 'render',
    'rendering', 'signature', 'stamp', 'poster', 'brochure', 'menu',
    'ticket', 'screenshot', 'template', 'coa',
  };

  static const Set<String> _stopWords = {'the', 'and', 'for', 'with', 'from', 'near'};

  // ───────────────────────── Public API ─────────────────────────

  /// Resolves an image URL and corrected title for a given keyword.
  ///
  /// [keyword] - the search term (e.g. Gemini's imageKeyword).
  /// [fallbackTitle] - the title to keep if no Wikipedia article matches.
  /// [lockIndex] - varies the LoremFlickr placeholder between activities.
  ///
  /// The returned title only differs from [fallbackTitle] when a Wikipedia
  /// article that really matches the place was found.
  static Future<ImageResolveResult> resolveImage({
    required String keyword,
    required String fallbackTitle,
    int lockIndex = 0,
  }) async {
    var resolvedTitle = fallbackTitle;
    final wanted = _tokens('$keyword $fallbackTitle');

    // 1 + 2. Wikipedia article (main image, then the article's other photos).
    final page = await _findWikipediaPage(keyword, wanted) ??
        (keyword.trim().toLowerCase() != fallbackTitle.trim().toLowerCase()
            ? await _findWikipediaPage(fallbackTitle, wanted)
            : null);

    String imgUrl = '';
    if (page != null) {
      resolvedTitle = page.title;
      imgUrl = page.photoUrl ?? await _photoFromArticle(page.title) ?? '';
    }

    // 3. Wikimedia Commons photo whose name matches the place.
    if (imgUrl.isEmpty) {
      final query = page?.title ?? keyword;
      imgUrl =
          await _photoFromCommons(query, _tokens(query).union(wanted)) ?? '';
    }

    // 4. Placeholder.
    if (imgUrl.isEmpty) {
      final keywordQuery = Uri.encodeComponent(
        keyword.replaceAll(RegExp(r'\s+'), ','),
      );
      imgUrl = 'https://loremflickr.com/600/400/$keywordQuery?lock=$lockIndex';
    }

    return ImageResolveResult(imageUrl: imgUrl, correctedTitle: resolvedTitle);
  }

  // ───────────────────────── Step 1: Wikipedia page ─────────────────────────

  static Future<_WikiPage?> _findWikipediaPage(
    String query,
    Set<String> wanted,
  ) async {
    if (query.trim().isEmpty) return null;

    final data = await _getJson(
      Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': query,
        'gsrlimit': '5',
        'prop': 'pageimages',
        'piprop': 'thumbnail|name',
        'pithumbsize': '800',
        'pilimit': '5',
        'format': 'json',
        'origin': '*',
      }),
    );
    final pages = (data?['query']?['pages'] as Map?)?.values.toList();
    if (pages == null || pages.isEmpty) return null;

    pages.sort(
      (a, b) => ((a['index'] as num?) ?? 99).compareTo((b['index'] as num?) ?? 99),
    );

    // First (best-ranked) article that is really about the place.
    for (final p in pages) {
      final title = (p['title'] ?? '').toString();
      if (title.isEmpty || title.startsWith('File:')) continue;
      if (!_isRelevant(_tokens(title), wanted)) continue;

      String? photoUrl;
      final thumb = p['thumbnail'] as Map?;
      final fileName = (p['pageimage'] ?? '').toString();
      if (thumb != null &&
          _looksLikePhoto(
            name: fileName,
            width: (thumb['width'] as num?)?.toInt() ?? 0,
            height: (thumb['height'] as num?)?.toInt() ?? 0,
          )) {
        photoUrl = thumb['source'] as String?;
      }
      return _WikiPage(title, photoUrl);
    }
    return null;
  }

  // ───────────────────────── Step 2: photos inside the article ─────────────────────────

  static Future<String?> _photoFromArticle(String title) async {
    final listing = await _getJson(
      Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'titles': title,
        'prop': 'images',
        'imlimit': '50',
        'format': 'json',
        'origin': '*',
      }),
    );
    final article = (listing?['query']?['pages'] as Map?)?.values.firstOrNull;
    final files = ((article?['images'] as List?) ?? const [])
        .map((i) => (i['title'] ?? '').toString())
        .where((t) => t.startsWith('File:') && _nameLooksLikePhoto(t))
        .take(20)
        .toList();
    if (files.isEmpty) return null;

    final info = await _getJson(_imageInfoUri(titles: files.join('|')));
    final best = _pickBest(_candidates(info), _tokens(title), requireNameMatch: false);
    return best?.url;
  }

  // ───────────────────────── Step 3: Commons ─────────────────────────

  static Future<String?> _photoFromCommons(
    String query,
    Set<String> wanted,
  ) async {
    if (query.trim().isEmpty) return null;
    final data = await _getJson(
      Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': '$query filemime:image/jpeg',
        'gsrnamespace': '6',
        'gsrlimit': '12',
        'prop': 'imageinfo',
        'iiprop': 'url|size|mime',
        'iiurlwidth': '800',
        'format': 'json',
        'origin': '*',
      }),
    );
    // Commons search also matches descriptions, so require the FILE NAME to
    // mention the place; otherwise a stray unrelated photo could slip in.
    return _pickBest(_candidates(data), wanted, requireNameMatch: true)?.url;
  }

  // ───────────────────────── Candidate checks ─────────────────────────

  static Uri _imageInfoUri({required String titles}) =>
      Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'titles': titles,
        'prop': 'imageinfo',
        'iiprop': 'url|size|mime',
        'iiurlwidth': '800',
        'format': 'json',
        'origin': '*',
      });

  static List<_Candidate> _candidates(Map<String, dynamic>? data) {
    final pages = (data?['query']?['pages'] as Map?)?.values ?? const [];
    final result = <_Candidate>[];
    for (final p in pages) {
      final infoList = p['imageinfo'] as List?;
      if (infoList == null || infoList.isEmpty) continue;
      final info = infoList.first as Map;
      final mime = (info['mime'] ?? '').toString();
      if (mime != 'image/jpeg') continue;
      final name = (p['title'] ?? '').toString();
      final w = (info['width'] as num?)?.toInt() ?? 0;
      final h = (info['height'] as num?)?.toInt() ?? 0;
      if (!_looksLikePhoto(name: name, width: w, height: h)) continue;
      final url = (info['thumburl'] ?? info['url'] ?? '').toString();
      if (url.isEmpty) continue;
      result.add(_Candidate(url: url, name: name, width: w, height: h));
    }
    return result;
  }

  /// Best candidate by: file name mentions the place, landscape shape, size.
  static _Candidate? _pickBest(
    List<_Candidate> candidates,
    Set<String> wanted, {
    required bool requireNameMatch,
  }) {
    _Candidate? best;
    var bestScore = double.negativeInfinity;
    for (final c in candidates) {
      final overlap = _tokens(_baseName(c.name)).intersection(wanted).length;
      if (requireNameMatch && overlap == 0) continue;

      final ratio = c.height == 0 ? 0.0 : c.width / c.height;
      var score = overlap * 3.0;
      if (ratio >= 1.2 && ratio <= 2.0) score += 1.0; // typical landscape photo
      score += (c.width.clamp(0, 2000)) / 2000.0;
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }

  /// A real, usable photo: JPEG, not named like a graphic, big enough, and a
  /// sensible shape.
  static bool _looksLikePhoto({
    required String name,
    required int width,
    required int height,
  }) {
    if (!_nameLooksLikePhoto(name)) return false;
    if (width < 400 || height < 250) return false;
    final ratio = width / height;
    return ratio >= 0.6 && ratio <= 3.0;
  }

  static bool _nameLooksLikePhoto(String name) {
    final lower = name.toLowerCase();
    if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg'))) return false;
    final words = _baseName(name)
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.isNotEmpty);
    return !words.any(_graphicWords.contains);
  }

  static String _baseName(String name) {
    var n = name.replaceFirst(RegExp(r'^File:', caseSensitive: false), '');
    final dot = n.lastIndexOf('.');
    if (dot > 0) n = n.substring(0, dot);
    return n.replaceAll('_', ' ');
  }

  // ───────────────────────── Relevance helpers ─────────────────────────

  static Set<String> _tokens(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .split(' ')
      .where((t) => t.length >= 3 && !_stopWords.contains(t))
      .toSet();

  /// The article title must share at least half of its words with what we are
  /// looking for (and at least one), so "Nasi Lemak Wanjo" never adopts an
  /// unrelated article just because it was the top search hit.
  static bool _isRelevant(Set<String> titleTokens, Set<String> wanted) {
    if (titleTokens.isEmpty || wanted.isEmpty) return false;
    final shared = titleTokens.intersection(wanted).length;
    if (shared == 0) return false;
    final smaller = titleTokens.length < wanted.length
        ? titleTokens.length
        : wanted.length;
    return shared / smaller >= 0.5;
  }

  static Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    try {
      final res = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

class _WikiPage {
  final String title;

  /// The article's main image if it passed the photo checks, else null.
  final String? photoUrl;
  const _WikiPage(this.title, this.photoUrl);
}

class _Candidate {
  final String url;
  final String name;
  final int width;
  final int height;
  const _Candidate({
    required this.url,
    required this.name,
    required this.width,
    required this.height,
  });
}
