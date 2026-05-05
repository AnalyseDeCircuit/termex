import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/toggle.dart';
import 'package:termex/widgets/checkbox.dart';
import 'package:termex/widgets/radio.dart';

class ToggleCheckboxRadioPage extends StatefulWidget {
  const ToggleCheckboxRadioPage({super.key});

  @override
  State<ToggleCheckboxRadioPage> createState() =>
      _ToggleCheckboxRadioPageState();
}

class _ToggleCheckboxRadioPageState extends State<ToggleCheckboxRadioPage> {
  // Toggle state
  bool _toggle1 = false;
  bool _toggle2 = true;

  // Checkbox state
  bool? _check1 = false;
  bool? _check2 = true;
  bool? _check3; // indeterminate (null)

  // Radio state
  String _radioValue = 'A';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toggle / Checkbox / Radio',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),

          // Toggle section
          _Section(
            title: 'Toggle',
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TermexToggle(
                  value: _toggle1,
                  onChanged: (v) => setState(() => _toggle1 = v),
                ),
                TermexToggle(
                  value: _toggle2,
                  onChanged: (v) => setState(() => _toggle2 = v),
                ),
                const TermexToggle(
                  value: false,
                  disabled: true,
                ),
                TermexToggle(
                  value: _toggle1,
                  label: 'Enable feature',
                  onChanged: (v) => setState(() => _toggle1 = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Checkbox section
          _Section(
            title: 'Checkbox',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TermexCheckbox(
                  value: _check1,
                  label: 'Unchecked',
                  onChanged: (v) => setState(() => _check1 = v),
                ),
                const SizedBox(height: 12),
                TermexCheckbox(
                  value: _check2,
                  label: 'Checked',
                  onChanged: (v) => setState(() => _check2 = v),
                ),
                const SizedBox(height: 12),
                TermexCheckbox(
                  value: _check3,
                  label: 'Indeterminate',
                  tristate: true,
                  onChanged: (v) => setState(() => _check3 = v),
                ),
                const SizedBox(height: 12),
                const TermexCheckbox(
                  value: false,
                  label: 'Disabled',
                  disabled: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Radio section
          _Section(
            title: 'Radio Group (A / B / C)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TermexRadio<String>(
                  value: 'A',
                  groupValue: _radioValue,
                  label: 'Option A',
                  onChanged: (v) => setState(() => _radioValue = v),
                ),
                const SizedBox(height: 12),
                TermexRadio<String>(
                  value: 'B',
                  groupValue: _radioValue,
                  label: 'Option B',
                  onChanged: (v) => setState(() => _radioValue = v),
                ),
                const SizedBox(height: 12),
                TermexRadio<String>(
                  value: 'C',
                  groupValue: _radioValue,
                  label: 'Option C',
                  onChanged: (v) => setState(() => _radioValue = v),
                ),
              ],
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
