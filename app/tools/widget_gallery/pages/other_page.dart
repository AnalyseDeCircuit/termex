import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/badge.dart';
import 'package:termex/widgets/avatar.dart';
import 'package:termex/widgets/divider.dart';
import 'package:termex/widgets/card.dart';
import 'package:termex/widgets/skeleton.dart';
import 'package:termex/widgets/accordion.dart';

class OtherPage extends StatelessWidget {
  const OtherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Badge / Avatar / Divider / Card / Skeleton / Accordion',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),

          // Badge section
          _Section(
            title: 'Badge',
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TermexBadge(
                  count: 3,
                  child: _BadgeTarget(label: 'Count 3'),
                ),
                TermexBadge(
                  count: 120,
                  maxCount: 99,
                  child: _BadgeTarget(label: 'Count 120'),
                ),
                TermexBadge(
                  dot: true,
                  variant: BadgeVariant.dot,
                  child: _BadgeTarget(label: 'Dot'),
                ),
                TermexBadge(
                  count: 0,
                  child: _BadgeTarget(label: 'Zero (hidden)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Avatar section
          _Section(
            title: 'Avatar',
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TermexAvatar(
                  initials: 'JD',
                  size: AvatarSize.small,
                ),
                TermexAvatar(
                  initials: 'AB',
                  size: AvatarSize.medium,
                ),
                TermexAvatar(
                  initials: 'XY',
                  size: AvatarSize.large,
                ),
                const TermexAvatar(
                  icon: _UserIcon(),
                  size: AvatarSize.medium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Divider section
          _Section(
            title: 'Divider',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Horizontal divider:',
                  style: TermexTypography.bodySmall.copyWith(
                    color: TermexColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const TermexDivider(),
                const SizedBox(height: 16),
                Text(
                  'With indent:',
                  style: TermexTypography.bodySmall.copyWith(
                    color: TermexColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const TermexDivider(indent: 24, endIndent: 24),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Vertical:',
                      style: TermexTypography.bodySmall.copyWith(
                        color: TermexColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 32,
                      child: const TermexDivider(direction: Axis.vertical),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'divides here',
                      style: TermexTypography.bodySmall.copyWith(
                        color: TermexColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Card section
          _Section(
            title: 'Card',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TermexCard(
                  title: 'Server Status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'prod-web-01 is running normally.',
                        style: TermexTypography.body.copyWith(
                          color: TermexColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CPU: 12%  |  Memory: 48%  |  Uptime: 99.9%',
                        style: TermexTypography.bodySmall.copyWith(
                          color: TermexColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TermexCard(
                  bordered: false,
                  elevation: TermexElevation.e2,
                  child: Text(
                    'Card with elevation, no border.',
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Skeleton section
          _Section(
            title: 'Skeleton',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                TermexSkeleton(width: 200, height: 16),
                SizedBox(height: 8),
                TermexSkeleton(height: 12),
                SizedBox(height: 8),
                TermexSkeleton(width: 280, height: 12),
                SizedBox(height: 16),
                TermexSkeleton(
                  height: 80,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Accordion section
          _Section(
            title: 'Accordion',
            child: TermexAccordion(
              multiple: true,
              initialOpenKeys: const {'item-1'},
              items: [
                AccordionItem(
                  key: 'item-1',
                  title: 'SSH Configuration',
                  contentBuilder: (ctx) => Text(
                    'Configure SSH key, port forwarding, and connection parameters here.',
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.textSecondary,
                    ),
                  ),
                ),
                AccordionItem(
                  key: 'item-2',
                  title: 'Environment Variables',
                  contentBuilder: (ctx) => Text(
                    'Set environment variables for this server session.',
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.textSecondary,
                    ),
                  ),
                ),
                AccordionItem(
                  key: 'item-3',
                  title: 'Advanced Options',
                  contentBuilder: (ctx) => Text(
                    'Keepalive interval, compression, cipher suite, and proxy jump.',
                    style: TermexTypography.body.copyWith(
                      color: TermexColors.textSecondary,
                    ),
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

class _BadgeTarget extends StatelessWidget {
  final String label;

  const _BadgeTarget({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TermexColors.backgroundTertiary,
        borderRadius: TermexRadius.sm,
        border: Border.all(color: TermexColors.border),
      ),
      child: Text(
        label,
        style: TermexTypography.bodySmall.copyWith(
          color: TermexColors.textPrimary,
        ),
      ),
    );
  }
}

class _UserIcon extends StatelessWidget {
  const _UserIcon();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(16, 16),
      painter: _UserIconPainter(),
    );
  }
}

class _UserIconPainter extends CustomPainter {
  const _UserIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TermexColors.textSecondary
      ..style = PaintingStyle.fill;

    // Head circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.35),
      size.width * 0.22,
      paint,
    );

    // Body arc
    final bodyPath = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width / 2,
        size.height * 0.6,
        size.width,
        size.height,
      )
      ..close();
    canvas.drawPath(bodyPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
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
