import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Termex icon set — line icons matching the Vue/Tauri build's design.
///
/// The Vue stack drew icons inline as 24×24 stroke-based SVGs in the
/// Lucide style (stroke-width 2, round caps/joins, currentColor). The
/// `lucide_icons` Flutter package ships the same icon set as a font, so
/// each [TermexIcons] constant aliases to its Lucide equivalent.
///
/// Centralising the alias here means call sites (TermexIconWidget,
/// `Icon(TermexIcons.foo)`) keep working without churn — only the visual
/// glyph changes from MaterialIcons to Lucide.
class TermexIcons {
  TermexIcons._();

  // ── Servers / Connection ─────────────────────────────────────────────────
  static const IconData server      = LucideIcons.server;
  static const IconData terminal    = LucideIcons.terminal;
  static const IconData connect     = LucideIcons.plug;
  static const IconData disconnect  = LucideIcons.unplug;
  static const IconData portForward = LucideIcons.network;
  static const IconData proxy       = LucideIcons.globe;
  static const IconData sftp        = LucideIcons.folderInput;

  // ── Files / Folders ──────────────────────────────────────────────────────
  static const IconData file       = LucideIcons.file;
  static const IconData folder     = LucideIcons.folder;
  static const IconData folderOpen = LucideIcons.folderOpen;
  static const IconData upload     = LucideIcons.upload;
  static const IconData download   = LucideIcons.download;

  // ── App chrome ───────────────────────────────────────────────────────────
  static const IconData settings = LucideIcons.settings;
  static const IconData menu     = LucideIcons.menu;
  static const IconData help     = LucideIcons.helpCircle;
  static const IconData moon     = LucideIcons.moon;
  static const IconData sun      = LucideIcons.sun;
  static const IconData history  = LucideIcons.history;

  // ── Common actions ───────────────────────────────────────────────────────
  static const IconData add     = LucideIcons.plus;
  static const IconData remove  = LucideIcons.minus;
  static const IconData edit    = LucideIcons.pencil;
  static const IconData delete  = LucideIcons.trash2;
  static const IconData close   = LucideIcons.x;
  static const IconData check   = LucideIcons.check;
  static const IconData search  = LucideIcons.search;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData copy    = LucideIcons.copy;
  static const IconData paste   = LucideIcons.clipboard;
  static const IconData filter  = LucideIcons.filter;
  static const IconData sort    = LucideIcons.arrowUpDown;

  // ── Auth / Security ──────────────────────────────────────────────────────
  static const IconData lock   = LucideIcons.lock;
  static const IconData unlock = LucideIcons.unlock;
  static const IconData key    = LucideIcons.key;
  static const IconData user   = LucideIcons.user;
  static const IconData group  = LucideIcons.users;

  // ── Cloud / AI / Monitor ─────────────────────────────────────────────────
  static const IconData cloud   = LucideIcons.cloud;
  static const IconData ai      = LucideIcons.brain;
  static const IconData monitor = LucideIcons.monitor;

  // ── Recording playback ───────────────────────────────────────────────────
  static const IconData record = LucideIcons.circle;
  static const IconData play   = LucideIcons.play;
  static const IconData pause  = LucideIcons.pause;
  static const IconData stop   = LucideIcons.square;

  // ── Status indicators ────────────────────────────────────────────────────
  static const IconData info    = LucideIcons.info;
  static const IconData warning = LucideIcons.alertTriangle;
  static const IconData error   = LucideIcons.alertCircle;
  static const IconData success = LucideIcons.checkCircle;
  static const IconData bell    = LucideIcons.bell;

  // ── Arrows / Chevrons ────────────────────────────────────────────────────
  static const IconData arrowUp      = LucideIcons.arrowUp;
  static const IconData arrowDown    = LucideIcons.arrowDown;
  static const IconData arrowLeft    = LucideIcons.arrowLeft;
  static const IconData arrowRight   = LucideIcons.arrowRight;
  static const IconData chevronUp    = LucideIcons.chevronUp;
  static const IconData chevronDown  = LucideIcons.chevronDown;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData moreHoriz    = LucideIcons.moreHorizontal;
  static const IconData moreVert     = LucideIcons.moreVertical;

  // ── Layout ───────────────────────────────────────────────────────────────
  static const IconData expand     = LucideIcons.maximize;
  static const IconData collapse   = LucideIcons.minimize;
  static const IconData splitHoriz = LucideIcons.columns;
  static const IconData splitVert  = LucideIcons.rows;

  // ── Misc ─────────────────────────────────────────────────────────────────
  static const IconData git          = LucideIcons.gitBranch;
  static const IconData snippet      = LucideIcons.scroll;
  static const IconData eye          = LucideIcons.eye;
  static const IconData eyeOff       = LucideIcons.eyeOff;
  static const IconData tag          = LucideIcons.tag;
  static const IconData star         = LucideIcons.star;
  static const IconData link         = LucideIcons.link;
  static const IconData externalLink = LucideIcons.externalLink;
}

/// Convenience widget that renders a [TermexIcons] glyph with the project's
/// default size and text color. Existing call sites just pass the icon:
///
///   TermexIconWidget(TermexIcons.lock, size: 28, color: TermexColors.primary)
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
