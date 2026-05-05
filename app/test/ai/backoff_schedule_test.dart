import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/ai/state/backoff_schedule.dart';

void main() {
  group('computeBackoffSeconds — default (SENTINEL=false)', () {
    test('returns 1 for attempt 0', () {
      expect(computeBackoffSeconds(0, 0), 1);
    });

    test('doubles each attempt up to cap', () {
      expect(computeBackoffSeconds(0, 1), 2);
      expect(computeBackoffSeconds(0, 2), 4);
      expect(computeBackoffSeconds(0, 3), 8);
      expect(computeBackoffSeconds(0, 4), 16);
      expect(computeBackoffSeconds(0, 5), 32);
      expect(computeBackoffSeconds(0, 6), 64);
    });

    test('caps attempt index at 6 to prevent shift overflow', () {
      expect(computeBackoffSeconds(0, 10), 64);
      expect(computeBackoffSeconds(0, 100), 64);
    });

    test('tier does not affect default-path value', () {
      expect(computeBackoffSeconds(0, 3), 8);
      expect(computeBackoffSeconds(3, 3), 8);
      expect(computeBackoffSeconds(99, 3), 8);
    });
  });
}
