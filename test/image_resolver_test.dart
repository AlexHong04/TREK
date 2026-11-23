import 'dart:convert';

import 'package:Trek/models/configurations/image_resolver_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builds a fake Wikipedia/Commons API from simple fixtures so the resolver's
/// decisions can be tested without the network.
class _FakeApi {
  /// generator=search on en.wikipedia.org -> pages
  Map<String, dynamic> wikiSearchPages = {};

  /// prop=images listing -> file titles
  List<String> articleFiles = [];

  /// imageinfo results keyed by "File:..." title -> [w, h, mime]
  Map<String, List<dynamic>> fileInfo = {};

  /// Commons search results (file titles)
  List<String> commonsFiles = [];

  final requests = <Uri>[];

  http.Client client() => MockClient((req) async {
    requests.add(req.url);
    final q = req.url.queryParameters;
    final host = req.url.host;

    Map<String, dynamic> pagesFor(List<String> files) => {
      'query': {
        'pages': {
          for (var i = 0; i < files.length; i++)
            '$i': {
              'title': files[i],
              'imageinfo': [
                {
                  'thumburl': 'https://thumb/${files[i]}',
                  'url': 'https://full/${files[i]}',
                  'width': fileInfo[files[i]]?[0] ?? 1600,
                  'height': fileInfo[files[i]]?[1] ?? 1000,
                  'mime': fileInfo[files[i]]?[2] ?? 'image/jpeg',
                },
              ],
            },
        },
      },
    };

    if (host == 'commons.wikimedia.org') {
      return http.Response(jsonEncode(pagesFor(commonsFiles)), 200);
    }
    if (q['generator'] == 'search') {
      return http.Response(jsonEncode({'query': {'pages': wikiSearchPages}}), 200);
    }
    if (q['prop'] == 'images') {
      return http.Response(
        jsonEncode({
          'query': {
            'pages': {
              '1': {
                'images': [
                  for (final f in articleFiles) {'ns': 6, 'title': f},
                ],
              },
            },
          },
        }),
        200,
      );
    }
    if (q['prop'] == 'imageinfo') {
      final wanted = q['titles']!.split('|');
      return http.Response(jsonEncode(pagesFor(wanted)), 200);
    }
    return http.Response('{}', 404);
  });
}

Map<String, dynamic> _page(
  String title, {
  String? image,
  int w = 800,
  int h = 533,
  int index = 1,
}) => {
  'title': title,
  'index': index,
  if (image != null) 'pageimage': image,
  if (image != null)
    'thumbnail': {'source': 'https://wiki-thumb/$image', 'width': w, 'height': h},
};

void main() {
  late _FakeApi api;

  setUp(() {
    api = _FakeApi();
    ImageResolverConfig.client = api.client();
  });

  test('uses the article main image when it is a real photo', () async {
    api.wikiSearchPages = {
      '1': _page('Petronas Towers', image: 'Petronas_Towers_night.jpg'),
    };
    final r = await ImageResolverConfig.resolveImage(
      keyword: 'Petronas Towers',
      fallbackTitle: 'Petronas Twin Towers',
    );
    expect(r.imageUrl, 'https://wiki-thumb/Petronas_Towers_night.jpg');
    expect(r.correctedTitle, 'Petronas Towers');
    expect(api.requests.length, 1, reason: 'no extra lookups needed');
  });

  test('rejects an SVG logo and picks a photo from the same article', () async {
    api.wikiSearchPages = {
      '1': _page('Old Town White Coffee', image: 'Old_Town_White_Coffee_logo.svg'),
    };
    api.articleFiles = [
      'File:Old_Town_White_Coffee_logo.svg',
      'File:Map_of_outlets.jpg',
      'File:Old_Town_White_Coffee_Ipoh_shop.jpg',
      'File:Commons-logo.png',
    ];
    final r = await ImageResolverConfig.resolveImage(
      keyword: 'Old Town White Coffee',
      fallbackTitle: 'Old Town White Coffee',
    );
    expect(r.imageUrl, 'https://thumb/File:Old_Town_White_Coffee_Ipoh_shop.jpg');
  });

  test('rejects a JPEG whose name says it is a map or flag', () async {
    api.wikiSearchPages = {
      '1': _page('Penang', image: 'Penang_location_map.jpg'),
    };
    api.articleFiles = ['File:Flag_of_Penang.jpg', 'File:Penang_skyline.jpg'];
    final r = await ImageResolverConfig.resolveImage(
      keyword: 'Penang',
      fallbackTitle: 'Penang',
    );
    expect(r.imageUrl, 'https://thumb/File:Penang_skyline.jpg');
  });

  test('ignores tiny and extreme-shaped images', () async {
    api.wikiSearchPages = {
      '1': _page('Batu Caves', image: 'Batu_Caves_tiny.jpg', w: 120, h: 90),
    };
    api.articleFiles = ['File:Batu_Caves_strip.jpg', 'File:Batu_Caves_steps.jpg'];
    api.fileInfo = {
      'File:Batu_Caves_strip.jpg': [3000, 200, 'image/jpeg'],
      'File:Batu_Caves_steps.jpg': [1600, 1067, 'image/jpeg'],
    };
    final r = await ImageResolverConfig.resolveImage(
      keyword: 'Batu Caves',
      fallbackTitle: 'Batu Caves',
    );
    expect(r.imageUrl, 'https://thumb/File:Batu_Caves_steps.jpg');
  });

  test('an unrelated top search hit is not adopted (title is kept)', () async {
    api.wikiSearchPages = {
      '1': _page('Lemak', image: 'Coconut.jpg'),
    };
    api.commonsFiles = [];
    final r = await ImageResolverConfig.resolveImage(
      keyword: 'Wanjo Special Kitchen',
      fallbackTitle: 'Wanjo Special Kitchen',
      lockIndex: 7,
    );
    expect(r.correctedTitle, 'Wanjo Special Kitchen');
    expect(r.imageUrl, startsWith('https://loremflickr.com/'));
    expect(r.imageUrl, contains('lock=7'));
  });

  test('Commons photos must mention the place in the file name', () async {
    api.wikiSearchPages = {};
    api.commonsFiles = [
      'File:Random_sunset_beach.jpg',
      'File:Pasar_Malam_Jalan_Alor_stalls.jpg',
    ];
    final r = await ImageResolverConfig.resolveImage(
      keyword: 'Jalan Alor night market',
      fallbackTitle: 'Jalan Alor',
    );
    expect(r.imageUrl, 'https://thumb/File:Pasar_Malam_Jalan_Alor_stalls.jpg');
  });

  test('falls back to the placeholder when the network fails', () async {
    ImageResolverConfig.client = MockClient((_) async => throw Exception('offline'));
    final r = await ImageResolverConfig.resolveImage(
      keyword: 'Langkawi Sky Bridge',
      fallbackTitle: 'Langkawi Sky Bridge',
    );
    expect(r.imageUrl, startsWith('https://loremflickr.com/'));
    expect(r.correctedTitle, 'Langkawi Sky Bridge');
  });
}
