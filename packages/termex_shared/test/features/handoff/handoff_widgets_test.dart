import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termex_shared/features/handoff/model/handoff_view_model.dart';
import 'package:termex_shared/features/handoff/widgets/send_to_device_dialog.dart';
import 'package:termex_shared/features/handoff/widgets/taken_over_banner.dart';
import 'package:termex_shared/features/handoff/widgets/takeover_confirm_dialog.dart';
import 'package:termex_shared/features/handoff/widgets/watcher_badge.dart';

Widget host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 700)),
        child: child,
      ),
    );

DeviceVM dev({
  String id = 'd1',
  String name = 'iPhone',
  DevicePlatformVM platform = DevicePlatformVM.ios,
  bool isSelf = false,
  bool isOnline = true,
  DateTime? lastSeenAt,
}) =>
    DeviceVM(
      id: id,
      name: name,
      platform: platform,
      lastSeenAt: lastSeenAt ?? DateTime.utc(2026, 5, 23, 12, 0, 0),
      isSelf: isSelf,
      isOnline: isOnline,
    );

void main() {
  group('WatcherBadge', () {
    testWidgets('shows "Only this device" when no other watchers',
        (tester) async {
      await tester.pumpWidget(host(WatcherBadge(
        watchers: [dev(isSelf: true)],
      )));
      expect(find.text('Only this device'), findsOneWidget);
    });

    testWidgets('singular label for one other watcher', (tester) async {
      await tester.pumpWidget(host(WatcherBadge(
        watchers: [dev(isSelf: true), dev(id: 'd2', name: 'Mac')],
      )));
      expect(find.text('1 other watching'), findsOneWidget);
    });

    testWidgets('plural label for multiple other watchers', (tester) async {
      await tester.pumpWidget(host(WatcherBadge(
        watchers: [
          dev(isSelf: true),
          dev(id: 'd2', name: 'Mac'),
          dev(id: 'd3', name: 'Linux'),
        ],
      )));
      expect(find.text('2 others watching'), findsOneWidget);
    });

    testWidgets('tap invokes the supplied callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(host(WatcherBadge(
        watchers: [dev(isSelf: true), dev(id: 'd2', name: 'Mac')],
        onTap: () => tapped = true,
      )));
      await tester.tap(find.text('1 other watching'));
      expect(tapped, isTrue);
    });
  });

  group('SendToDeviceDialog', () {
    testWidgets('renders empty-state hint when only self present',
        (tester) async {
      await tester.pumpWidget(host(SendToDeviceDialog(
        devices: [dev(isSelf: true)],
        onSend: (_) {},
        onCancel: () {},
      )));
      expect(find.text('No other devices registered.'), findsOneWidget);
    });

    testWidgets('lists each non-self device with status line', (tester) async {
      final now = DateTime.utc(2026, 5, 23, 12, 0, 0);
      await tester.pumpWidget(host(SendToDeviceDialog(
        devices: [
          dev(isSelf: true),
          dev(id: 'd2', name: 'Mac', platform: DevicePlatformVM.macos),
          dev(
            id: 'd3',
            name: 'Old Phone',
            platform: DevicePlatformVM.android,
            isOnline: false,
            lastSeenAt: now.subtract(const Duration(hours: 2)),
          ),
        ],
        onSend: (_) {},
        onCancel: () {},
        now: now,
      )));
      expect(find.text('Mac'), findsOneWidget);
      expect(find.text('macOS · online'), findsOneWidget);
      expect(find.text('Old Phone'), findsOneWidget);
      expect(find.text('Android · 2h ago'), findsOneWidget);
    });

    testWidgets('tap fires onSend with the chosen device', (tester) async {
      DeviceVM? target;
      await tester.pumpWidget(host(SendToDeviceDialog(
        devices: [
          dev(isSelf: true),
          dev(id: 'd2', name: 'Mac'),
        ],
        onSend: (d) => target = d,
        onCancel: () {},
      )));
      await tester.tap(find.text('Mac'));
      expect(target?.id, 'd2');
    });

    testWidgets('cancel fires onCancel', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(host(SendToDeviceDialog(
        devices: [dev(isSelf: true)],
        onSend: (_) {},
        onCancel: () => cancelled = true,
      )));
      await tester.tap(find.text('Cancel'));
      expect(cancelled, isTrue);
    });
  });

  group('TakeoverConfirmDialog', () {
    testWidgets('shows current owner name + buttons', (tester) async {
      await tester.pumpWidget(host(TakeoverConfirmDialog(
        currentOwnerName: 'iPhone 14',
        onConfirm: () {},
        onCancel: () {},
      )));
      expect(find.text('Take over task?'), findsOneWidget);
      expect(find.textContaining('iPhone 14 is the current owner'),
          findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Take over'), findsOneWidget);
    });

    testWidgets('takeover button fires onConfirm', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(host(TakeoverConfirmDialog(
        currentOwnerName: 'iPhone',
        onConfirm: () => confirmed = true,
        onCancel: () {},
      )));
      await tester.tap(find.text('Take over'));
      expect(confirmed, isTrue);
    });
  });

  group('TakenOverBanner', () {
    testWidgets('renders the new owner label', (tester) async {
      await tester.pumpWidget(host(const TakenOverBanner(
        newOwnerName: 'Work Mac',
      )));
      expect(find.text('Taken over by Work Mac'), findsOneWidget);
    });

    testWidgets('take-back button only shown when callback provided',
        (tester) async {
      await tester.pumpWidget(host(const TakenOverBanner(
        newOwnerName: 'Work Mac',
      )));
      expect(find.text('Take back'), findsNothing);

      await tester.pumpWidget(host(TakenOverBanner(
        newOwnerName: 'Work Mac',
        onTakeBack: () {},
      )));
      expect(find.text('Take back'), findsOneWidget);
    });

    testWidgets('tap fires onTakeBack', (tester) async {
      var fired = false;
      await tester.pumpWidget(host(TakenOverBanner(
        newOwnerName: 'Work Mac',
        onTakeBack: () => fired = true,
      )));
      await tester.tap(find.text('Take back'));
      expect(fired, isTrue);
    });
  });
}
