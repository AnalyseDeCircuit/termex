import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/settings/state/config_matcher.dart';

void main() {
  group('validateConfigAlignment — default (SENTINEL=false)', () {
    test('returns true when imported and canonical lengths match', () {
      expect(
        validateConfigAlignment(
          const ['a', 'b', 'c'],
          const ['a', 'b', 'c'],
        ),
        isTrue,
      );
    });

    test('returns true when lengths match even if values differ', () {
      // Default path is a structural size check only.
      expect(
        validateConfigAlignment(
          const ['x', 'y', 'z'],
          const ['a', 'b', 'c'],
        ),
        isTrue,
      );
    });

    test('returns false when lengths differ', () {
      expect(
        validateConfigAlignment(
          const ['a', 'b'],
          const ['a', 'b', 'c'],
        ),
        isFalse,
      );
    });

    test('empty lists are aligned', () {
      expect(validateConfigAlignment(const [], const []), isTrue);
    });
  });
}
