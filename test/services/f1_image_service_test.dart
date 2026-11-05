import 'package:flutter_test/flutter_test.dart';
import 'package:gridglance/services/f1_image_service.dart';

void main() {
  final service = F1ImageService.instance;

  group('F1ImageService.carImageUrl', () {
    // Constructor IDs Jolpica reports for the 2026 season.
    const constructors2026 = {
      'alpine': 'alpine',
      'aston_martin': 'astonmartin',
      'audi': 'audi',
      'cadillac': 'cadillac',
      'ferrari': 'ferrari',
      'haas': 'haasf1team',
      'mclaren': 'mclaren',
      'mercedes': 'mercedes',
      'rb': 'racingbulls',
      'red_bull': 'redbullracing',
      'williams': 'williams',
    };

    test('maps every 2026 constructor to its F1 media path', () {
      const season = F1ImageService.carImageSeason;
      for (final entry in constructors2026.entries) {
        final url = service.carImageUrl(entry.key);
        expect(url, isNotNull, reason: entry.key);
        expect(
          url,
          endsWith(
            '/common/f1/$season/${entry.value}/$season${entry.value}carright.webp',
          ),
          reason: entry.key,
        );
      }
    });

    test('requests PNG so native widgets can decode the bytes', () {
      expect(service.carImageUrl('mclaren'), contains('/f_png/'));
    });

    test('never points at the retired 2025 asset path', () {
      expect(service.carImageUrl('ferrari'), isNot(contains('fom-website')));
    });

    test('maps legacy sauber to the Audi car', () {
      expect(service.carImageUrl('sauber'), service.carImageUrl('audi'));
    });

    test('returns null for unknown constructors', () {
      expect(service.carImageUrl('brawn'), isNull);
    });
  });
}
