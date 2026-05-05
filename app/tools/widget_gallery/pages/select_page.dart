import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/select.dart';

class SelectPage extends StatefulWidget {
  const SelectPage({super.key});

  @override
  State<SelectPage> createState() => _SelectPageState();
}

class _SelectPageState extends State<SelectPage> {
  String? _selected1;
  String? _selected2;

  static const _options5 = [
    SelectOption(value: 'ubuntu', label: 'Ubuntu 22.04'),
    SelectOption(value: 'debian', label: 'Debian 12'),
    SelectOption(value: 'centos', label: 'CentOS Stream 9'),
    SelectOption(value: 'arch', label: 'Arch Linux'),
    SelectOption(value: 'alpine', label: 'Alpine 3.18'),
  ];

  static const _options10 = [
    SelectOption(value: 'us-east-1', label: 'US East (N. Virginia)'),
    SelectOption(value: 'us-east-2', label: 'US East (Ohio)'),
    SelectOption(value: 'us-west-1', label: 'US West (N. California)'),
    SelectOption(value: 'us-west-2', label: 'US West (Oregon)'),
    SelectOption(value: 'eu-west-1', label: 'EU (Ireland)'),
    SelectOption(value: 'eu-central-1', label: 'EU (Frankfurt)'),
    SelectOption(value: 'ap-southeast-1', label: 'Asia Pacific (Singapore)'),
    SelectOption(value: 'ap-northeast-1', label: 'Asia Pacific (Tokyo)'),
    SelectOption(value: 'ap-south-1', label: 'Asia Pacific (Mumbai)'),
    SelectOption(value: 'sa-east-1', label: 'South America (Sao Paulo)'),
    SelectOption(value: 'ca-central-1', label: 'Canada (Central)'),
    SelectOption(value: 'af-south-1', label: 'Africa (Cape Town)'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Normal (5 options)',
            child: SizedBox(
              width: 320,
              child: TermexSelect<String>(
                options: _options5,
                value: _selected1,
                placeholder: 'Select OS distribution',
                onChanged: (v) => setState(() => _selected1 = v),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Searchable (12 options)',
            child: SizedBox(
              width: 320,
              child: TermexSelect<String>(
                options: _options10,
                value: _selected2,
                placeholder: 'Search region...',
                searchable: true,
                onChanged: (v) => setState(() => _selected2 = v),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Disabled',
            child: SizedBox(
              width: 320,
              child: TermexSelect<String>(
                options: _options5,
                value: 'ubuntu',
                placeholder: 'Select OS',
                disabled: true,
                onChanged: null,
              ),
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
