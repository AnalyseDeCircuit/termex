// Placeholder widget test — kept to satisfy `flutter test` discovery.
//
// The default `Counter increments smoke test` shipped by `flutter create`
// referenced a `MyApp` class that doesn't exist in Termex; the real app
// entry is `TermexApp` from `main.dart`. Coverage for the actual UI lives
// in test/features/**.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, equals(2));
  });
}
