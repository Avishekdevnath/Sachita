import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/core/services/update_service.dart';

void main() {
  group('UpdateService.isLowerVersion', () {
    test('same version returns false', () {
      expect(UpdateService.isLowerVersion('1.0.0', '1.0.0'), isFalse);
    });

    test('lower major returns true', () {
      expect(UpdateService.isLowerVersion('0.9.0', '1.0.0'), isTrue);
    });

    test('higher major returns false', () {
      expect(UpdateService.isLowerVersion('2.0.0', '1.0.0'), isFalse);
    });

    test('equal major, lower minor returns true', () {
      expect(UpdateService.isLowerVersion('1.1.9', '1.2.0'), isTrue);
    });

    test('equal major, higher minor returns false', () {
      expect(UpdateService.isLowerVersion('1.2.0', '1.1.9'), isFalse);
    });

    test('equal major+minor, lower patch returns true', () {
      expect(UpdateService.isLowerVersion('1.0.0', '1.0.1'), isTrue);
    });

    test('equal major+minor, higher patch returns false', () {
      expect(UpdateService.isLowerVersion('1.0.1', '1.0.0'), isFalse);
    });

    test('malformed version returns false (safe fallback)', () {
      expect(UpdateService.isLowerVersion('bad', '1.0.0'), isFalse);
    });
  });
}
