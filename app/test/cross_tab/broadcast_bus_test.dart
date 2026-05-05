import 'package:flutter_test/flutter_test.dart';

import 'package:termex/cross_tab/broadcast_bus.dart';

void main() {
  group('BroadcastBus', () {
    test('on<T> receives typed events', () async {
      final bus = BroadcastBus.instance;
      final received = <ServerUpdated>[];
      final sub = bus.on<ServerUpdated>().listen(received.add);

      bus.emit(ServerUpdated('srv-1'));
      bus.emit(ThemeChanged('dark')); // different type, should not appear
      bus.emit(ServerUpdated('srv-2'));

      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(2));
      expect(received[0].serverId, equals('srv-1'));
      expect(received[1].serverId, equals('srv-2'));
      await sub.cancel();
    });

    test('ThemeChanged event is received', () async {
      final bus = BroadcastBus.instance;
      final modes = <String>[];
      final sub = bus.on<ThemeChanged>().listen((e) => modes.add(e.mode));

      bus.emit(ThemeChanged('light'));
      bus.emit(ThemeChanged('dark'));

      await Future<void>.delayed(Duration.zero);
      expect(modes, equals(['light', 'dark']));
      await sub.cancel();
    });

    test('MasterLockTriggered received by multiple listeners', () async {
      final bus = BroadcastBus.instance;
      int count = 0;
      final sub1 = bus.on<MasterLockTriggered>().listen((_) => count++);
      final sub2 = bus.on<MasterLockTriggered>().listen((_) => count++);

      bus.emit(MasterLockTriggered());

      await Future<void>.delayed(Duration.zero);
      expect(count, equals(2));
      await sub1.cancel();
      await sub2.cancel();
    });

    test('SettingsChanged carries key', () async {
      final bus = BroadcastBus.instance;
      String? key;
      final sub =
          bus.on<SettingsChanged>().listen((e) => key = e.key);

      bus.emit(SettingsChanged('theme_mode'));

      await Future<void>.delayed(Duration.zero);
      expect(key, equals('theme_mode'));
      await sub.cancel();
    });

    test('SessionClosed carries sessionId', () async {
      final bus = BroadcastBus.instance;
      String? id;
      final sub =
          bus.on<SessionClosed>().listen((e) => id = e.sessionId);

      bus.emit(SessionClosed('sess-abc'));

      await Future<void>.delayed(Duration.zero);
      expect(id, equals('sess-abc'));
      await sub.cancel();
    });
  });
}
