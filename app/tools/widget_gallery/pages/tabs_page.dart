import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/tabs.dart';

class TabsPage extends StatefulWidget {
  const TabsPage({super.key});

  @override
  State<TabsPage> createState() => _TabsPageState();
}

class _TabsPageState extends State<TabsPage> {
  int _underlineIndex = 0;
  int _pillsIndex = 1;
  int _segmentedIndex = 0;

  static const _tabs = [
    TabItem(label: 'Terminal'),
    TabItem(label: 'SFTP'),
    TabItem(label: 'Settings'),
    TabItem(label: 'Logs'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tabs',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Underline',
            child: TermexTabs(
              tabs: _tabs,
              activeIndex: _underlineIndex,
              variant: TabVariant.underline,
              onChanged: (i) => setState(() => _underlineIndex = i),
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Pills',
            child: TermexTabs(
              tabs: _tabs,
              activeIndex: _pillsIndex,
              variant: TabVariant.pills,
              onChanged: (i) => setState(() => _pillsIndex = i),
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Segmented',
            child: TermexTabs(
              tabs: _tabs,
              activeIndex: _segmentedIndex,
              variant: TabVariant.segmented,
              onChanged: (i) => setState(() => _segmentedIndex = i),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TermexTypography.heading4.copyWith(
            color: TermexColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
