import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

import 'button_page.dart';
import 'text_field_page.dart';
import 'select_page.dart';
import 'dialog_page.dart';
import 'toggle_checkbox_radio_page.dart';
import 'tabs_page.dart';
import 'tree_page.dart';
import 'slider_page.dart';
import 'table_page.dart';
import 'toast_page.dart';
import 'other_page.dart';

const _widgetNames = [
  'Button',
  'IconButton',
  'TextField',
  'Select',
  'Menu',
  'Dialog',
  'Toast',
  'Tooltip',
  'Popover',
  'Tabs',
  'Tree',
  'List',
  'DataTable',
  'Toggle',
  'Checkbox',
  'Radio',
  'Slider',
  'Badge',
  'Avatar',
  'Divider',
  'Card',
  'Skeleton',
  'Accordion',
];

class GalleryHome extends StatefulWidget {
  const GalleryHome({super.key});

  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends State<GalleryHome> {
  int _selectedIndex = 0;

  Widget _pageForIndex(int index) {
    switch (index) {
      case 0:
        return const ButtonPage();
      case 1:
        return const IconButtonPage();
      case 2:
        return const TextFieldPage();
      case 3:
        return const SelectPage();
      case 4:
        return const MenuPage();
      case 5:
        return const DialogPage();
      case 6:
        return const ToastPage();
      case 7:
        return const TooltipPage();
      case 8:
        return const PopoverPage();
      case 9:
        return const TabsPage();
      case 10:
        return const TreePage();
      case 11:
        return const ListPage();
      case 12:
        return const TablePage();
      case 13:
        return const ToggleCheckboxRadioPage();
      case 14:
        return const ToggleCheckboxRadioPage();
      case 15:
        return const ToggleCheckboxRadioPage();
      case 16:
        return const SliderPage();
      case 17:
        return const OtherPage();
      case 18:
        return const OtherPage();
      case 19:
        return const OtherPage();
      case 20:
        return const OtherPage();
      case 21:
        return const OtherPage();
      case 22:
        return const OtherPage();
      default:
        return const ButtonPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TermexColors.backgroundPrimary,
      child: Row(
        children: [
          _Sidebar(
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
          ),
          Container(
            width: 1,
            color: TermexColors.border,
          ),
          Expanded(
            child: _pageForIndex(_selectedIndex),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: ColoredBox(
        color: TermexColors.backgroundSecondary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              child: Text(
                'Widget Gallery',
                style: TermexTypography.heading4.copyWith(
                  color: TermexColors.textPrimary,
                ),
              ),
            ),
            Container(height: 1, color: TermexColors.border),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _widgetNames.length,
                itemBuilder: (ctx, i) => _NavItem(
                  label: _widgetNames[i],
                  selected: selectedIndex == i,
                  onTap: () => onSelect(i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final showBg = widget.selected || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: showBg ? TermexColors.backgroundTertiary : null,
            border: widget.selected
                ? const Border(
                    left: BorderSide(
                      color: TermexColors.primary,
                      width: 2,
                    ),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Text(
            widget.label,
            style: TermexTypography.bodySmall.copyWith(
              color: widget.selected
                  ? TermexColors.textPrimary
                  : TermexColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// Stub pages for widgets not given dedicated pages
class IconButtonPage extends StatelessWidget {
  const IconButtonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(name: 'IconButton');
  }
}

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(name: 'Menu');
  }
}

class TooltipPage extends StatelessWidget {
  const TooltipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(name: 'Tooltip');
  }
}

class PopoverPage extends StatelessWidget {
  const PopoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(name: 'Popover');
  }
}

class ListPage extends StatelessWidget {
  const ListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubPage(name: 'List');
  }
}

class _StubPage extends StatelessWidget {
  final String name;

  const _StubPage({required this.name});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(
        '$name Gallery',
        style: TermexTypography.heading3.copyWith(
          color: TermexColors.textPrimary,
        ),
      ),
    );
  }
}
