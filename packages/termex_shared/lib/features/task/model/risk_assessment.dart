/// Dart mirror of `termex_core::task::risk::RiskAssessment`.
library;

enum RiskLevel { low, medium, high, critical;

  bool get requiresAttention => this != RiskLevel.low;

  String get displayName {
    switch (this) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
      case RiskLevel.critical:
        return 'Critical';
    }
  }

  static RiskLevel fromWire(String s) {
    switch (s) {
      case 'critical':
        return RiskLevel.critical;
      case 'high':
        return RiskLevel.high;
      case 'medium':
        return RiskLevel.medium;
      default:
        return RiskLevel.low;
    }
  }
}

class RiskAssessment {
  final RiskLevel level;
  final List<String> reasons;
  final List<String> matchedPatterns;
  final String preview;

  const RiskAssessment({
    required this.level,
    this.reasons = const [],
    this.matchedPatterns = const [],
    this.preview = '',
  });

  factory RiskAssessment.fromJson(Map<String, dynamic> j) {
    return RiskAssessment(
      level: RiskLevel.fromWire(j['level'] as String? ?? 'low'),
      reasons: (j['reasons'] as List?)?.cast<String>() ?? const [],
      matchedPatterns:
          (j['matched_patterns'] as List?)?.cast<String>() ?? const [],
      preview: j['preview'] as String? ?? '',
    );
  }
}

enum RiskPolicy { auto, alwaysConfirm, neverConfirm;

  String get wireName {
    switch (this) {
      case RiskPolicy.auto:
        return 'auto';
      case RiskPolicy.alwaysConfirm:
        return 'always_confirm';
      case RiskPolicy.neverConfirm:
        return 'never_confirm';
    }
  }

  String get displayName {
    switch (this) {
      case RiskPolicy.auto:
        return 'Auto (recommended)';
      case RiskPolicy.alwaysConfirm:
        return 'Always confirm';
      case RiskPolicy.neverConfirm:
        return 'Never confirm';
    }
  }
}
