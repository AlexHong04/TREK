// Dev tool: shows which image the app would pick for each place name.
//
//   dart run tool/probe_images.dart "Petronas Twin Towers" "Batu Caves"
//
// Opens real Wikipedia/Commons requests (no API key needed). Handy for
// judging image quality and tuning the checks in image_resolver_config.dart.
import 'package:Trek/models/configurations/image_resolver_config.dart';

Future<void> main(List<String> args) async {
  final places = args.isNotEmpty
      ? args
      : const [
          'Petronas Twin Towers',
          'Batu Caves',
          'Jonker Street Melaka',
          'Old Town White Coffee',
          'Penang Hill',
          'Langkawi Sky Bridge',
          'George Town Penang',
          'Kuala Lumpur',
          'Nasi Kandar Pelita',
        ];
  for (final place in places) {
    final r = await ImageResolverConfig.resolveImage(
      keyword: place,
      fallbackTitle: place,
    );
    final source = r.imageUrl.contains('loremflickr') ? 'PLACEHOLDER' : 'photo';
    print('$place\n  title: ${r.correctedTitle}\n  [$source] ${r.imageUrl}\n');
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
