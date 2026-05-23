import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/task/model/risk_assessment.dart';

void main() {
  group('RiskLevel.fromWire', () {
    test('roundtrips known variants', () {
      expect(RiskLevel.fromWire('critical'), RiskLevel.critical);
      expect(RiskLevel.fromWire('high'), RiskLevel.high);
      expect(RiskLevel.fromWire('medium'), RiskLevel.medium);
      expect(RiskLevel.fromWire('low'), RiskLevel.low);
    });
    test('unknown defaults to low', () {
      expect(RiskLevel.fromWire('xyz'), RiskLevel.low);
    });
    test('requiresAttention classification', () {
      expect(RiskLevel.low.requiresAttention, isFalse);
      expect(RiskLevel.medium.requiresAttention, isTrue);
      expect(RiskLevel.high.requiresAttention, isTrue);
      expect(RiskLevel.critical.requiresAttention, isTrue);
    });
  });

  group('RiskAssessment.fromJson', () {
    test('parses full payload', () {
      final a = RiskAssessment.fromJson({
        'level': 'high',
        'reasons': ['sudo invocation', 'Server tagged as production'],
        'matched_patterns': [r'(?i)\bsudo\b'],
        'preview': 'sudo systemctl restart nginx',
      });
      expect(a.level, RiskLevel.high);
      expect(a.reasons, hasLength(2));
      expect(a.matchedPatterns, hasLength(1));
      expect(a.preview, 'sudo systemctl restart nginx');
    });

    test('tolerates missing keys with defaults', () {
      final a = RiskAssessment.fromJson({});
      expect(a.level, RiskLevel.low);
      expect(a.reasons, isEmpty);
      expect(a.preview, '');
    });
  });

  group('RiskPolicy.wireName', () {
    test('uses snake_case to match termex_core::risk::RiskPolicy', () {
      expect(RiskPolicy.auto.wireName, 'auto');
      expect(RiskPolicy.alwaysConfirm.wireName, 'always_confirm');
      expect(RiskPolicy.neverConfirm.wireName, 'never_confirm');
    });
  });
}
