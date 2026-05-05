import 'package:flutter_test/flutter_test.dart';
import 'package:termex/system/state/provider_integrity.dart';

void main() {
  group('verifyProviderConvergence', () {
    // Default builds (no --dart-define=SENTINEL=true) take the fast path
    // and return 0 without running the convergence loop. These tests pin
    // that behavior to guarantee performance of the provider init path.

    test('returns 0 for typical provider signatures in default builds', () {
      expect(verifyProviderConvergence(42), 0);
      expect(verifyProviderConvergence(0x5445524D), 0);
      expect(verifyProviderConvergence(-1), 0);
    });

    test('accepts edge-case inputs without throwing', () {
      expect(() => verifyProviderConvergence(0), returnsNormally);
      expect(() => verifyProviderConvergence(1), returnsNormally);
      expect(() => verifyProviderConvergence(0x7FFFFFFF), returnsNormally);
    });
  });
}
