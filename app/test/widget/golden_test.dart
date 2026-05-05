import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:termex/widgets/avatar.dart';
import 'package:termex/widgets/badge.dart';
import 'package:termex/widgets/button.dart';
import 'package:termex/widgets/card.dart';
import 'package:termex/widgets/checkbox.dart';
import 'package:termex/widgets/divider.dart';
import 'package:termex/widgets/tabs.dart';
import 'package:termex/widgets/toggle.dart';

import 'test_helpers.dart';

void main() {
  group('Widget Goldens', () {
    // TermexButton
    testGoldens('TermexButton primary', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(const TermexButton(label: 'Connect')),
      );
      await screenMatchesGolden(tester, 'button_primary');
    });

    testGoldens('TermexButton secondary', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const TermexButton(
            label: 'Cancel',
            variant: ButtonVariant.secondary,
          ),
        ),
      );
      await screenMatchesGolden(tester, 'button_secondary');
    });

    testGoldens('TermexButton ghost', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const TermexButton(
            label: 'Details',
            variant: ButtonVariant.ghost,
          ),
        ),
      );
      await screenMatchesGolden(tester, 'button_ghost');
    });

    testGoldens('TermexButton danger', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const TermexButton(
            label: 'Delete',
            variant: ButtonVariant.danger,
          ),
        ),
      );
      await screenMatchesGolden(tester, 'button_danger');
    });

    testGoldens('TermexButton disabled', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const TermexButton(
            label: 'Connect',
            disabled: true,
          ),
        ),
      );
      await screenMatchesGolden(tester, 'button_disabled');
    });

    testGoldens('TermexButton loading', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const TermexButton(
            label: 'Connecting',
            loading: true,
          ),
        ),
      );
      // CircularProgressIndicator never stops animating so pumpAndSettle would
      // time out — use a single-frame pump to capture the loading spinner
      // at frame 0.
      await screenMatchesGolden(
        tester,
        'button_loading',
        customPump: (tester) => tester.pump(const Duration(milliseconds: 16)),
      );
    });

    // TermexCheckbox
    testGoldens('TermexCheckbox unchecked', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(const TermexCheckbox(value: false)),
      );
      await screenMatchesGolden(tester, 'checkbox_unchecked');
    });

    testGoldens('TermexCheckbox checked', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(const TermexCheckbox(value: true)),
      );
      await screenMatchesGolden(tester, 'checkbox_checked');
    });

    // TermexToggle
    testGoldens('TermexToggle off', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(const TermexToggle(value: false)),
      );
      await screenMatchesGolden(tester, 'toggle_off');
    });

    testGoldens('TermexToggle on', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(const TermexToggle(value: true)),
      );
      await screenMatchesGolden(tester, 'toggle_on');
    });

    // TermexBadge
    testGoldens('TermexBadge count', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const TermexBadge(
            count: 7,
            child: SizedBox(width: 24, height: 24),
          ),
        ),
      );
      await screenMatchesGolden(tester, 'badge_count');
    });

    testGoldens('TermexBadge dot', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const TermexBadge(
            dot: true,
            variant: BadgeVariant.dot,
            child: SizedBox(width: 24, height: 24),
          ),
        ),
      );
      await screenMatchesGolden(tester, 'badge_dot');
    });

    // TermexDivider
    testGoldens('TermexDivider horizontal', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const SizedBox(width: 200, child: TermexDivider()),
        ),
      );
      await screenMatchesGolden(tester, 'divider_horizontal');
    });

    // TermexCard
    testGoldens('TermexCard with title', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const TermexCard(
            title: 'Server Info',
            child: Text('prod-01'),
          ),
        ),
      );
      await screenMatchesGolden(tester, 'card_with_title');
    });

    testGoldens('TermexCard without title', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const TermexCard(child: Text('prod-01')),
        ),
      );
      await screenMatchesGolden(tester, 'card_without_title');
    });

    // TermexAvatar
    testGoldens('TermexAvatar initials', (tester) async {
      await loadAppFonts();
      await tester.pumpWidgetBuilder(
        wrapWidget(
          const TermexAvatar(initials: 'TX'),
        ),
      );
      await screenMatchesGolden(tester, 'avatar_initials');
    });
  });
}
