import 'package:flutter/widgets.dart';

// Temporary icon implementation using Flutter's built-in font
// Will be replaced with SVG-based icons in v0.48 polish iteration
class TermexIcons {
  TermexIcons._();

  static const _fontFamily = 'MaterialIcons';

  static const IconData server        = IconData(0xe59b, fontFamily: _fontFamily);
  static const IconData terminal      = IconData(0xe336, fontFamily: _fontFamily);
  static const IconData file          = IconData(0xe24d, fontFamily: _fontFamily);
  static const IconData folder        = IconData(0xe2c7, fontFamily: _fontFamily);
  static const IconData folderOpen    = IconData(0xe2c8, fontFamily: _fontFamily);
  static const IconData settings      = IconData(0xe8b8, fontFamily: _fontFamily);
  static const IconData add           = IconData(0xe145, fontFamily: _fontFamily);
  static const IconData remove        = IconData(0xe15b, fontFamily: _fontFamily);
  static const IconData edit          = IconData(0xe3c9, fontFamily: _fontFamily);
  static const IconData delete        = IconData(0xe872, fontFamily: _fontFamily);
  static const IconData close         = IconData(0xe5cd, fontFamily: _fontFamily);
  static const IconData check         = IconData(0xe876, fontFamily: _fontFamily);
  static const IconData search        = IconData(0xe8b6, fontFamily: _fontFamily);
  static const IconData refresh       = IconData(0xe5d5, fontFamily: _fontFamily);
  static const IconData copy          = IconData(0xe14d, fontFamily: _fontFamily);
  static const IconData paste         = IconData(0xe14f, fontFamily: _fontFamily);
  static const IconData upload        = IconData(0xe2c6, fontFamily: _fontFamily);
  static const IconData download      = IconData(0xe2c0, fontFamily: _fontFamily);
  static const IconData connect       = IconData(0xe63a, fontFamily: _fontFamily);
  static const IconData disconnect    = IconData(0xe63b, fontFamily: _fontFamily);
  static const IconData lock          = IconData(0xe897, fontFamily: _fontFamily);
  static const IconData unlock        = IconData(0xe898, fontFamily: _fontFamily);
  static const IconData key           = IconData(0xe73c, fontFamily: _fontFamily);
  static const IconData user          = IconData(0xe7fd, fontFamily: _fontFamily);
  static const IconData group         = IconData(0xe7ef, fontFamily: _fontFamily);
  static const IconData cloud         = IconData(0xe2bd, fontFamily: _fontFamily);
  static const IconData ai            = IconData(0xe553, fontFamily: _fontFamily);
  static const IconData monitor       = IconData(0xe339, fontFamily: _fontFamily);
  static const IconData record        = IconData(0xe061, fontFamily: _fontFamily);
  static const IconData play          = IconData(0xe037, fontFamily: _fontFamily);
  static const IconData pause         = IconData(0xe034, fontFamily: _fontFamily);
  static const IconData stop          = IconData(0xe047, fontFamily: _fontFamily);
  static const IconData info          = IconData(0xe88e, fontFamily: _fontFamily);
  static const IconData warning       = IconData(0xe002, fontFamily: _fontFamily);
  static const IconData error         = IconData(0xe000, fontFamily: _fontFamily);
  static const IconData success       = IconData(0xe86c, fontFamily: _fontFamily);
  static const IconData arrowUp       = IconData(0xe5d8, fontFamily: _fontFamily);
  static const IconData arrowDown     = IconData(0xe5db, fontFamily: _fontFamily);
  static const IconData arrowLeft     = IconData(0xe5c4, fontFamily: _fontFamily);
  static const IconData arrowRight    = IconData(0xe5c8, fontFamily: _fontFamily);
  static const IconData chevronUp     = IconData(0xe5ce, fontFamily: _fontFamily);
  static const IconData chevronDown   = IconData(0xe5cf, fontFamily: _fontFamily);
  static const IconData chevronRight  = IconData(0xe5cc, fontFamily: _fontFamily);
  static const IconData moreHoriz     = IconData(0xe5d3, fontFamily: _fontFamily);
  static const IconData moreVert      = IconData(0xe5d4, fontFamily: _fontFamily);
  static const IconData menu          = IconData(0xe5d2, fontFamily: _fontFamily);
  static const IconData expand        = IconData(0xe5d0, fontFamily: _fontFamily);
  static const IconData collapse      = IconData(0xe5d1, fontFamily: _fontFamily);
  static const IconData splitHoriz    = IconData(0xe3bc, fontFamily: _fontFamily);
  static const IconData splitVert     = IconData(0xe3bd, fontFamily: _fontFamily);
  static const IconData git           = IconData(0xe30d, fontFamily: _fontFamily);
  static const IconData snippet       = IconData(0xe86f, fontFamily: _fontFamily);
  static const IconData portForward   = IconData(0xe9ba, fontFamily: _fontFamily);
  static const IconData proxy         = IconData(0xe0c7, fontFamily: _fontFamily);
  static const IconData sftp          = IconData(0xe2c4, fontFamily: _fontFamily);
  static const IconData eye           = IconData(0xe8f4, fontFamily: _fontFamily);
  static const IconData eyeOff        = IconData(0xe8f5, fontFamily: _fontFamily);
  static const IconData sort          = IconData(0xe164, fontFamily: _fontFamily);
  static const IconData filter        = IconData(0xef4f, fontFamily: _fontFamily);
  static const IconData tag           = IconData(0xe892, fontFamily: _fontFamily);
  static const IconData star          = IconData(0xe838, fontFamily: _fontFamily);
  static const IconData link          = IconData(0xe157, fontFamily: _fontFamily);
  static const IconData externalLink  = IconData(0xe89e, fontFamily: _fontFamily);
  static const IconData help          = IconData(0xe887, fontFamily: _fontFamily);
  static const IconData moon          = IconData(0xef44, fontFamily: _fontFamily);
  static const IconData sun           = IconData(0xe518, fontFamily: _fontFamily);
}

class TermexIconWidget extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  const TermexIconWidget(this.icon, {super.key, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color ?? const Color(0xFFE6EDF3));
  }
}
