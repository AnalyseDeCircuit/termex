typedef Validator<T> = String? Function(T value);

abstract final class Validators {
  static Validator<String> required({String message = '此项为必填'}) {
    return (value) => value.trim().isEmpty ? message : null;
  }

  static Validator<String> minLength(int n) {
    return (value) => value.length < n ? '最少 $n 个字符' : null;
  }

  static Validator<String> maxLength(int n) {
    return (value) => value.length > n ? '最多 $n 个字符' : null;
  }

  static Validator<String> email() {
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return (value) => re.hasMatch(value) ? null : '请输入有效的电子邮件地址';
  }

  static Validator<String> pattern(RegExp re, String message) {
    return (value) => re.hasMatch(value) ? null : message;
  }

  static Validator<String> compose(List<Validator<String>> vs) {
    return (value) {
      for (final v in vs) {
        final result = v(value);
        if (result != null) return result;
      }
      return null;
    };
  }

  static Validator<String> ipOrHostname() {
    final ipv4 = RegExp(
      r'^((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?)$',
    );
    final ipv6 = RegExp(r'^[\da-fA-F:]+$');
    final hostname = RegExp(
      r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$',
    );
    return (value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '请输入主机地址';
      if (ipv4.hasMatch(trimmed)) return null;
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        final inner = trimmed.substring(1, trimmed.length - 1);
        if (ipv6.hasMatch(inner)) return null;
      }
      if (hostname.hasMatch(trimmed)) return null;
      return '请输入有效的 IP 地址或主机名';
    };
  }
}

