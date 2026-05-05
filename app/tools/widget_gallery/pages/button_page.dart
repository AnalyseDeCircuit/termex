import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/button.dart';

class ButtonPage extends StatelessWidget {
  const ButtonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Button',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Variants',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TermexButton(
                  label: 'Primary',
                  variant: ButtonVariant.primary,
                  onPressed: () {},
                ),
                TermexButton(
                  label: 'Secondary',
                  variant: ButtonVariant.secondary,
                  onPressed: () {},
                ),
                TermexButton(
                  label: 'Ghost',
                  variant: ButtonVariant.ghost,
                  onPressed: () {},
                ),
                TermexButton(
                  label: 'Danger',
                  variant: ButtonVariant.danger,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Sizes',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TermexButton(
                  label: 'Small',
                  size: ButtonSize.small,
                  onPressed: () {},
                ),
                TermexButton(
                  label: 'Medium',
                  size: ButtonSize.medium,
                  onPressed: () {},
                ),
                TermexButton(
                  label: 'Large',
                  size: ButtonSize.large,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'States',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TermexButton(
                  label: 'Loading',
                  loading: true,
                  onPressed: () {},
                ),
                const TermexButton(
                  label: 'Disabled',
                  disabled: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'With Icon',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                TermexButton(
                  label: 'With Icon',
                  icon: const _PlusIcon(),
                  onPressed: () {},
                ),
                TermexButton(
                  label: 'Icon End',
                  icon: const _ArrowIcon(),
                  iconPosition: IconPosition.end,
                  onPressed: () {},
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

class _PlusIcon extends StatelessWidget {
  const _PlusIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(painter: _PlusIconPainter()),
    );
  }
}

class _PlusIconPainter extends CustomPainter {
  const _PlusIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ArrowIcon extends StatelessWidget {
  const _ArrowIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(painter: _ArrowIconPainter()),
    );
  }
}

class _ArrowIconPainter extends CustomPainter {
  const _ArrowIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(2, size.height / 2)
      ..lineTo(size.width - 2, size.height / 2)
      ..moveTo(size.width - 6, size.height / 2 - 4)
      ..lineTo(size.width - 2, size.height / 2)
      ..lineTo(size.width - 6, size.height / 2 + 4);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
