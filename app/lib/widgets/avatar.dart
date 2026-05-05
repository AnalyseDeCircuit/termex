import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';

enum AvatarSize { small, medium, large }

class TermexAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final Widget? icon;
  final AvatarSize size;
  final Color? backgroundColor;

  const TermexAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.icon,
    this.size = AvatarSize.medium,
    this.backgroundColor,
  });

  double get _dimension {
    switch (size) {
      case AvatarSize.small:
        return 24;
      case AvatarSize.medium:
        return 32;
      case AvatarSize.large:
        return 40;
    }
  }

  double get _fontSize {
    switch (size) {
      case AvatarSize.small:
        return 10;
      case AvatarSize.medium:
        return 13;
      case AvatarSize.large:
        return 16;
    }
  }

  Color _colorFromInitials(String text) {
    final palette = [
      const Color(0xFF2F81F7),
      const Color(0xFF3FB950),
      const Color(0xFFD29922),
      const Color(0xFFF85149),
      const Color(0xFF8957E5),
      const Color(0xFF39C5CF),
      const Color(0xFFDB6D28),
      const Color(0xFF6E7681),
    ];
    int hash = 0;
    for (final c in text.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return palette[hash % palette.length];
  }

  String _abbreviate(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return text.substring(0, text.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final d = _dimension;

    if (imageUrl != null) {
      return ClipOval(
        child: SizedBox(
          width: d,
          height: d,
          child: Image.network(
            imageUrl!,
            width: d,
            height: d,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallback(d),
          ),
        ),
      );
    }

    return ClipOval(child: _buildFallback(d));
  }

  Widget _buildFallback(double d) {
    if (initials != null && initials!.isNotEmpty) {
      final abbr = _abbreviate(initials!);
      final bg = backgroundColor ?? _colorFromInitials(initials!);
      return Container(
        width: d,
        height: d,
        color: bg,
        alignment: Alignment.center,
        child: Text(
          abbr,
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFFFFFF),
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    if (icon != null) {
      return Container(
        width: d,
        height: d,
        color: backgroundColor ?? TermexColors.backgroundTertiary,
        alignment: Alignment.center,
        child: icon,
      );
    }

    return Container(
      width: d,
      height: d,
      color: backgroundColor ?? TermexColors.backgroundTertiary,
      alignment: Alignment.center,
      child: Text(
        '?',
        style: TextStyle(
          fontSize: _fontSize,
          color: TermexColors.textSecondary,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
