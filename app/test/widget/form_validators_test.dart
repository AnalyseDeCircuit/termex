import 'package:flutter_test/flutter_test.dart';
import 'package:termex/widgets/form_validators.dart';

void main() {
  group('Validators.required', () {
    final v = Validators.required();

    test('returns null for non-empty string', () {
      expect(v('hello'), isNull);
    });

    test('returns error for empty string', () {
      expect(v(''), isNotNull);
    });

    test('returns error for whitespace-only string', () {
      expect(v('   '), isNotNull);
    });

    test('uses custom message', () {
      final cv = Validators.required(message: 'Required!');
      expect(cv(''), equals('Required!'));
    });
  });

  group('Validators.minLength', () {
    final v = Validators.minLength(5);

    test('returns null when length >= min', () {
      expect(v('hello'), isNull);
      expect(v('hello world'), isNull);
    });

    test('returns error when length < min', () {
      expect(v('hi'), isNotNull);
      expect(v(''), isNotNull);
    });
  });

  group('Validators.maxLength', () {
    final v = Validators.maxLength(3);

    test('returns null when length <= max', () {
      expect(v('hi'), isNull);
      expect(v('hey'), isNull);
    });

    test('returns error when length > max', () {
      expect(v('hello'), isNotNull);
    });
  });

  group('Validators.email', () {
    final v = Validators.email();

    test('returns null for valid email', () {
      expect(v('user@example.com'), isNull);
      expect(v('a+b@c.io'), isNull);
    });

    test('returns error for invalid email', () {
      expect(v('notanemail'), isNotNull);
      expect(v('@domain.com'), isNotNull);
      expect(v('user@'), isNotNull);
    });
  });

  group('Validators.pattern', () {
    final v = Validators.pattern(RegExp(r'^\d+$'), 'Digits only');

    test('returns null when pattern matches', () {
      expect(v('12345'), isNull);
    });

    test('returns error when pattern does not match', () {
      expect(v('abc'), equals('Digits only'));
    });
  });

  group('Validators.compose', () {
    final v = Validators.compose([
      Validators.required(),
      Validators.minLength(3),
    ]);

    test('returns null when all validators pass', () {
      expect(v('hello'), isNull);
    });

    test('returns first error when any validator fails', () {
      expect(v(''), isNotNull);
      expect(v('hi'), isNotNull);
    });
  });
}
