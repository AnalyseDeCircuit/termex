import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/slider.dart';

class SliderPage extends StatefulWidget {
  const SliderPage({super.key});

  @override
  State<SliderPage> createState() => _SliderPageState();
}

class _SliderPageState extends State<SliderPage> {
  double _continuous = 0.4;
  double _discrete = 50.0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Slider',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Continuous',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: TermexSlider(
                    value: _continuous,
                    onChanged: (v) => setState(() => _continuous = v),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Value: ${(_continuous * 100).toStringAsFixed(0)}%',
                  style: TermexTypography.bodySmall.copyWith(
                    color: TermexColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Discrete (10 divisions, 0–100)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: TermexSlider(
                    value: _discrete,
                    min: 0,
                    max: 100,
                    divisions: 10,
                    onChanged: (v) => setState(() => _discrete = v),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Value: ${_discrete.toStringAsFixed(0)}',
                  style: TermexTypography.bodySmall.copyWith(
                    color: TermexColors.textSecondary,
                  ),
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
