import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/recording/asciicast.dart';

const _header = '{"version":2,"width":120,"height":40}';

void main() {
  group('Cast.parse', () {
    test('reads geometry from the header', () {
      final c = Cast.parse(_header);
      expect(c.width, 120);
      expect(c.height, 40);
    });

    test('falls back to 80x24 without a header', () {
      final c = Cast.parse('[0.5,"o","hi"]');
      expect(c.width, 80);
      expect(c.height, 24);
      expect(c.events.single.data, 'hi');
    });

    test('keeps output events in order', () {
      final c = Cast.parse('$_header\n[0.1,"o","a"]\n[0.9,"o","b"]');
      expect(c.events.map((e) => e.data).toList(), ['a', 'b']);
      expect(c.events.first.time, closeTo(0.1, 1e-9));
    });

    // Input is recorded for auditing; replaying it would double every
    // keystroke, which the shell already echoed into the output stream.
    test('skips input events', () {
      final c = Cast.parse('$_header\n[0.1,"i","ls"]\n[0.2,"o","ls"]');
      expect(c.events.length, 1);
      expect(c.events.single.data, 'ls');
    });

    // A session that died mid-write leaves a partial last line; dropping the
    // whole recording over it would lose everything that did get captured.
    test('keeps what parsed when the file is truncated', () {
      final c = Cast.parse('$_header\n[0.1,"o","ok"]\n[0.2,"o","tru');
      expect(c.events.single.data, 'ok');
    });

    test('duration comes from the last event', () {
      final c = Cast.parse('$_header\n[0.1,"o","a"]\n[2.5,"o","b"]');
      expect(c.duration.inMilliseconds, 2500);
    });

    test('an empty recording has zero duration', () {
      expect(Cast.parse(_header).duration, Duration.zero);
    });
  });
}
