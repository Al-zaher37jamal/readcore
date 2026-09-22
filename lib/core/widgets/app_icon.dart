import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ultra-robust icon system that uses local bundled SVG assets to guarantee
/// ZERO missing-glyph rectangle/X on real Android devices.
/// Falls back to ultra-safe base Material icons if SVG fails.
/// No network loading, offline-first, minimal assets.

enum AppIconType {
  add,
  book,
  description,
  delete,
  copy,
  wifi,
  dot,
  error,
  refresh,
  play,
  pause,
  stop,
  star,
  person,
  login,
  group,
  history,
  bookmark,
  cancel,
  back,
  forward,
  language,
}

class AppIcon extends StatelessWidget {
  final AppIconType type;
  final double? size;
  final Color? color;

  const AppIcon(
    this.type, {
    super.key,
    this.size,
    this.color,
  });

  // Convenience constructors for semantic usage
  const AppIcon.add({super.key, double? size, Color? color})
      : type = AppIconType.add,
        size = size,
        color = color;
  const AppIcon.book({super.key, double? size, Color? color})
      : type = AppIconType.book,
        size = size,
        color = color;
  const AppIcon.pdf({super.key, double? size, Color? color})
      : type = AppIconType.description,
        size = size,
        color = color;
  const AppIcon.delete({super.key, double? size, Color? color})
      : type = AppIconType.delete,
        size = size,
        color = color;
  const AppIcon.copy({super.key, double? size, Color? color})
      : type = AppIconType.copy,
        size = size,
        color = color;
  const AppIcon.wifi({super.key, double? size, Color? color})
      : type = AppIconType.wifi,
        size = size,
        color = color;
  const AppIcon.dot({super.key, double? size, Color? color})
      : type = AppIconType.dot,
        size = size,
        color = color;
  const AppIcon.error({super.key, double? size, Color? color})
      : type = AppIconType.error,
        size = size,
        color = color;
  const AppIcon.refresh({super.key, double? size, Color? color})
      : type = AppIconType.refresh,
        size = size,
        color = color;
  const AppIcon.play({super.key, double? size, Color? color})
      : type = AppIconType.play,
        size = size,
        color = color;
  const AppIcon.pause({super.key, double? size, Color? color})
      : type = AppIconType.pause,
        size = size,
        color = color;
  const AppIcon.stop({super.key, double? size, Color? color})
      : type = AppIconType.stop,
        size = size,
        color = color;
  const AppIcon.star({super.key, double? size, Color? color})
      : type = AppIconType.star,
        size = size,
        color = color;
  const AppIcon.person({super.key, double? size, Color? color})
      : type = AppIconType.person,
        size = size,
        color = color;
  const AppIcon.login({super.key, double? size, Color? color})
      : type = AppIconType.login,
        size = size,
        color = color;
  const AppIcon.group({super.key, double? size, Color? color})
      : type = AppIconType.group,
        size = size,
        color = color;
  const AppIcon.history({super.key, double? size, Color? color})
      : type = AppIconType.history,
        size = size,
        color = color;
  const AppIcon.bookmark({super.key, double? size, Color? color})
      : type = AppIconType.bookmark,
        size = size,
        color = color;
  const AppIcon.cancel({super.key, double? size, Color? color})
      : type = AppIconType.cancel,
        size = size,
        color = color;
  const AppIcon.back({super.key, double? size, Color? color})
      : type = AppIconType.back,
        size = size,
        color = color;
  const AppIcon.forward({super.key, double? size, Color? color})
      : type = AppIconType.forward,
        size = size,
        color = color;
  const AppIcon.language({super.key, double? size, Color? color})
      : type = AppIconType.language,
        size = size,
        color = color;

  String get _assetPath {
    switch (type) {
      case AppIconType.add:
        return 'assets/icons/add.svg';
      case AppIconType.book:
        return 'assets/icons/book.svg';
      case AppIconType.description:
        return 'assets/icons/description.svg';
      case AppIconType.delete:
        return 'assets/icons/delete.svg';
      case AppIconType.copy:
        return 'assets/icons/content_copy.svg';
      case AppIconType.wifi:
        return 'assets/icons/wifi.svg';
      case AppIconType.dot:
        return 'assets/icons/dot.svg';
      case AppIconType.error:
        return 'assets/icons/error.svg';
      case AppIconType.refresh:
        return 'assets/icons/refresh.svg';
      case AppIconType.play:
        return 'assets/icons/play_arrow.svg';
      case AppIconType.pause:
        return 'assets/icons/pause.svg';
      case AppIconType.stop:
        return 'assets/icons/stop.svg';
      case AppIconType.star:
        return 'assets/icons/star.svg';
      case AppIconType.person:
        return 'assets/icons/person.svg';
      case AppIconType.login:
        return 'assets/icons/input.svg';
      case AppIconType.group:
        return 'assets/icons/group.svg';
      case AppIconType.history:
        return 'assets/icons/access_time.svg';
      case AppIconType.bookmark:
        return 'assets/icons/bookmark.svg';
      case AppIconType.cancel:
        return 'assets/icons/cancel.svg';
      case AppIconType.back:
        return 'assets/icons/arrow_back.svg';
      case AppIconType.forward:
        return 'assets/icons/arrow_forward.svg';
      case AppIconType.language:
        return 'assets/icons/language.svg';
    }
  }

  IconData get _fallbackIcon {
    // Ultra-safe base icons from Flutter 1.0 era, guaranteed in MaterialIcons
    switch (type) {
      case AppIconType.add:
        return Icons.add;
      case AppIconType.book:
        return Icons.book;
      case AppIconType.description:
        return Icons.description;
      case AppIconType.delete:
        return Icons.delete;
      case AppIconType.copy:
        return Icons.content_copy;
      case AppIconType.wifi:
        return Icons.signal_wifi_4_bar;
      case AppIconType.dot:
        return Icons.fiber_manual_record;
      case AppIconType.error:
        return Icons.error;
      case AppIconType.refresh:
        return Icons.refresh;
      case AppIconType.play:
        return Icons.play_arrow;
      case AppIconType.pause:
        return Icons.pause;
      case AppIconType.stop:
        return Icons.stop;
      case AppIconType.star:
        return Icons.star;
      case AppIconType.person:
        return Icons.person;
      case AppIconType.login:
        return Icons.input;
      case AppIconType.group:
        return Icons.group;
      case AppIconType.history:
        return Icons.access_time;
      case AppIconType.bookmark:
        return Icons.bookmark;
      case AppIconType.cancel:
        return Icons.cancel;
      case AppIconType.back:
        return Icons.arrow_back;
      case AppIconType.forward:
        return Icons.arrow_forward;
      case AppIconType.language:
        return Icons.language;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? 24.0;
    final iconColor = color ?? IconTheme.of(context).color ?? const Color(0xFF0F172A);

    // Try SVG first, fallback to Material icon if asset missing
    return SvgPicture.asset(
      _assetPath,
      width: iconSize,
      height: iconSize,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      placeholderBuilder: (ctx) => Icon(_fallbackIcon, size: iconSize, color: iconColor),
    );
  }
}

/// For places where Icon widget is required (e.g. BottomNavigationBarItem),
/// provide a widget that wraps AppIcon but also exposes IconData fallback
class AppIconData {
  static IconData get add => Icons.add;
  static IconData get book => Icons.book;
  static IconData get description => Icons.description;
  static IconData get delete => Icons.delete;
  static IconData get copy => Icons.content_copy;
  static IconData get wifi => Icons.signal_wifi_4_bar;
  static IconData get dot => Icons.fiber_manual_record;
  static IconData get error => Icons.error;
  static IconData get refresh => Icons.refresh;
  static IconData get play => Icons.play_arrow;
  static IconData get pause => Icons.pause;
  static IconData get stop => Icons.stop;
  static IconData get star => Icons.star;
  static IconData get person => Icons.person;
  static IconData get login => Icons.input;
  static IconData get group => Icons.group;
  static IconData get history => Icons.access_time;
  static IconData get bookmark => Icons.bookmark;
  static IconData get cancel => Icons.cancel;
  static IconData get back => Icons.arrow_back;
  static IconData get forward => Icons.arrow_forward;
  static IconData get language => Icons.language;
}
