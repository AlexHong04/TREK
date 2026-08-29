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

/// Handles image and title resolution from Wikipedia, Wikimedia Commons,
/// and LoremFlickr placeholder as a fallback chain.
class ImageResolverConfig {
  static const _wikiHeaders = {
    'User-Agent': 'TrekApp/1.0 (Flutter; travel itinerary generator)',
  };

  /// Resolves an image URL and corrected title for a given keyword.
  ///
  /// Resolution chain:
  /// 1. English Wikipedia (page image + title correction)
  /// 2. Wikimedia Commons (if Wikipedia had no image)
  /// 3. LoremFlickr placeholder (final fallback)
  ///
  /// [keyword] — the search term (e.g. activity destination name).
  /// [fallbackTitle] — the title to use if Wikipedia doesn't correct it.
  /// [lockIndex] — unique index for LoremFlickr cache-busting.
  static Future<ImageResolveResult> resolveImage({
    required String keyword,
    required String fallbackTitle,
    int lockIndex = 0,
  }) async {
    String imgUrl = '';
    String resolvedTitle = fallbackTitle;

    // ──────────────────────────────────────────────────
    // 1. English Wikipedia
    // ──────────────────────────────────────────────────
    try {
      final query = Uri.encodeComponent(keyword);
      final wikiUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=$query&gsrlimit=1&prop=pageimages&format=json&pithumbsize=600&origin=*',
      );
      final wikiRes = await http.get(wikiUrl, headers: _wikiHeaders);
      if (wikiRes.statusCode == 200) {
        final data = jsonDecode(wikiRes.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          final page = pages.values.first;
          if (page['title'] != null &&
              !page['title'].toString().startsWith('File:')) {
            resolvedTitle = page['title'];
          }
          if (page.containsKey('thumbnail')) {
            imgUrl = page['thumbnail']['source'] as String? ?? '';
          }
        }
      }
    } catch (_) {}

    // ──────────────────────────────────────────────────
    // 2. Wikimedia Commons (if Wikipedia had no image)
    // ──────────────────────────────────────────────────
    if (imgUrl.isEmpty) {
      try {
        final commonsQuery = Uri.encodeComponent(resolvedTitle);
        final commonsUrl = Uri.parse(
          'https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=$commonsQuery&gsrnamespace=6&gsrlimit=1&prop=imageinfo&iiprop=url&iiurlwidth=600&format=json&origin=*',
        );
        final commonsRes = await http.get(commonsUrl, headers: _wikiHeaders);
        if (commonsRes.statusCode == 200) {
          final data = jsonDecode(commonsRes.body);
          final pages = data['query']?['pages'] as Map<String, dynamic>?;
          if (pages != null && pages.isNotEmpty) {
            final page = pages.values.first;
            if (page.containsKey('imageinfo')) {
              final imageInfo = page['imageinfo'] as List;
              if (imageInfo.isNotEmpty && imageInfo[0]['thumburl'] != null) {
                imgUrl = imageInfo[0]['thumburl'] as String;
              }
            }
          }
        }
      } catch (_) {}
    }

    // ──────────────────────────────────────────────────
    // 3. LoremFlickr placeholder (final fallback)
    // ──────────────────────────────────────────────────
    if (imgUrl.isEmpty) {
      final keywordQuery = Uri.encodeComponent(
        keyword.replaceAll(RegExp(r'\s+'), ','),
      );
      imgUrl = 'https://loremflickr.com/600/400/$keywordQuery?lock=$lockIndex';
    }

    return ImageResolveResult(imageUrl: imgUrl, correctedTitle: resolvedTitle);
  }
}
