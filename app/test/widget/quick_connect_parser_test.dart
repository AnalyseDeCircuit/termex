import 'package:flutter_test/flutter_test.dart';
import 'package:termex/features/server_list/state/quick_connect_provider.dart';

void main() {
  group('QuickConnectParser', () {
    test('parses user@host', () {
      final r = QuickConnectParser.parse('admin@example.com');
      expect(r.username, 'admin');
      expect(r.host, 'example.com');
      expect(r.port, 22);
    });

    test('parses user@host:port', () {
      final r = QuickConnectParser.parse('ubuntu@10.0.0.1:2222');
      expect(r.username, 'ubuntu');
      expect(r.host, '10.0.0.1');
      expect(r.port, 2222);
    });

    test('parses host only', () {
      final r = QuickConnectParser.parse('example.com');
      expect(r.username, '');
      expect(r.host, 'example.com');
      expect(r.port, 22);
    });

    test('parses host:port', () {
      final r = QuickConnectParser.parse('example.com:8022');
      expect(r.username, '');
      expect(r.host, 'example.com');
      expect(r.port, 8022);
    });

    test('handles IPv4', () {
      final r = QuickConnectParser.parse('root@192.168.1.1:22');
      expect(r.username, 'root');
      expect(r.host, '192.168.1.1');
      expect(r.port, 22);
    });

    test('ignores invalid port, uses default 22', () {
      final r = QuickConnectParser.parse('host:notaport');
      expect(r.host, 'host:notaport');
      expect(r.port, 22);
    });

    test('strips leading/trailing whitespace', () {
      final r = QuickConnectParser.parse('  user@host  ');
      expect(r.username, 'user');
      expect(r.host, 'host');
    });
  });
}
