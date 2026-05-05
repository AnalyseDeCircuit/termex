import 'package:flutter_test/flutter_test.dart';

import 'package:termex/features/recording/asciicast_parser.dart';

void main() {
  group('AsciicastHeader', () {
    test('fromJson sets required fields', () {
      final h = AsciicastHeader.fromJson({
        'version': 2,
        'width': 120,
        'height': 30,
        'title': 'My Session',
      });
      expect(h.version, equals(2));
      expect(h.width, equals(120));
      expect(h.height, equals(30));
      expect(h.title, equals('My Session'));
      expect(h.duration, isNull);
    });

    test('fromJson uses defaults for missing optional fields', () {
      final h = AsciicastHeader.fromJson({'version': 2, 'width': 80, 'height': 24});
      expect(h.title, isNull);
      expect(h.env, isEmpty);
    });

    test('toJson round-trips', () {
      final h = AsciicastHeader(width: 80, height: 24, duration: 12.5, title: 'Test');
      final json = h.toJson();
      final h2 = AsciicastHeader.fromJson(json);
      expect(h2.width, equals(80));
      expect(h2.duration, equals(12.5));
      expect(h2.title, equals('Test'));
    });
  });

  group('AsciicastEvent', () {
    test('fromJson parses time/type/data', () {
      final e = AsciicastEvent.fromJson([1.234, 'o', 'hello']);
      expect(e.time, closeTo(1.234, 0.001));
      expect(e.type, equals('o'));
      expect(e.data, equals('hello'));
      expect(e.isOutput, isTrue);
    });

    test('input events are not output', () {
      final e = AsciicastEvent.fromJson([0.5, 'i', 'ls\n']);
      expect(e.isOutput, isFalse);
    });

    test('toJson round-trips', () {
      final e = AsciicastEvent(time: 2.0, type: 'o', data: 'world');
      final j = e.toJson();
      expect(j[0], equals(2.0));
      expect(j[1], equals('o'));
      expect(j[2], equals('world'));
    });
  });

  group('AsciicastFile', () {
    final _ndjson = '{"version":2,"width":80,"height":24}\n'
        '[0.5,"o","hello "]\n'
        '[1.0,"o","world"]\n'
        '[1.5,"i","ls\\n"]\n';

    test('decode parses header and events', () {
      final f = AsciicastFile.decode(_ndjson);
      expect(f.header.width, equals(80));
      expect(f.events, hasLength(3));
      expect(f.events.first.data, equals('hello '));
    });

    test('duration from last event', () {
      final f = AsciicastFile.decode(_ndjson);
      expect(f.duration, closeTo(1.5, 0.001));
    });

    test('visibleAt returns only output events up to time', () {
      final f = AsciicastFile.decode(_ndjson);
      final visible = f.visibleAt(1.0);
      expect(visible.length, equals(2));
      expect(visible.every((e) => e.isOutput), isTrue);
      expect(visible.last.data, equals('world'));
    });

    test('visibleAt excludes future events', () {
      final f = AsciicastFile.decode(_ndjson);
      expect(f.visibleAt(0.3), isEmpty);
    });

    test('encode produces valid NDJSON', () {
      final f = AsciicastFile.decode(_ndjson);
      final encoded = f.encode();
      final f2 = AsciicastFile.decode(encoded);
      expect(f2.events, hasLength(f.events.length));
    });

    test('decode throws on empty input', () {
      expect(() => AsciicastFile.decode(''), throwsA(isA<FormatException>()));
    });

    test('decode skips malformed event lines', () {
      final ndjson = '{"version":2,"width":80,"height":24}\n'
          '[0.5,"o","ok"]\n'
          'not-json-array\n'
          '[1.0,"o","also ok"]\n';
      final f = AsciicastFile.decode(ndjson);
      // The malformed line is silently skipped.
      expect(f.events, hasLength(2));
    });
  });
}
