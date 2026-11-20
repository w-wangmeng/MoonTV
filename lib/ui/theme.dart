import 'dart:ui';

import 'package:flutter/material.dart';

class MoonColors {
  MoonColors._();

  static const background = Color(0xFF060A13);
  static const background2 = Color(0xFF0B1424);
  static const surface = Color(0xFF101C31);
  static const surface2 = Color(0xFF162641);
  static const line = Color(0xFF23334E);
  static const text = Color(0xFFF4F7FF);
  static const muted = Color(0xFF8FA2BE);
  static const faint = Color(0xFF60728E);
  static const accent = Color(0xFF32B9E8);
  static const accentStrong = Color(0xFF7BE3FF);
  static const violet = Color(0xFF8E7DFF);
  static const gold = Color(0xFFF3C56B);
  static const success = Color(0xFF55D6A8);
  static const danger = Color(0xFFFF6B81);
}

ThemeData buildMoonTheme({bool tv = false}) {
  const scheme = ColorScheme.dark(
    primary: MoonColors.accent,
    onPrimary: Color(0xFF03141D),
    secondary: MoonColors.violet,
    onSecondary: Colors.white,
    surface: MoonColors.surface,
    onSurface: MoonColors.text,
    error: MoonColors.danger,
    onError: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: MoonColors.background,
  );

  final textTheme = base.textTheme
      .apply(bodyColor: MoonColors.text, displayColor: MoonColors.text)
      .copyWith(
        displayLarge: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
          height: 1.06,
        ),
        displayMedium: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          height: 1.08,
        ),
        headlineLarge: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
          height: 1.15,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          height: 1.25,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          height: 1.55,
          color: MoonColors.text,
        ),
        bodyMedium: const TextStyle(
          fontSize: 13.5,
          height: 1.55,
          color: MoonColors.muted,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          height: 1.45,
          color: MoonColors.faint,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelMedium: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    focusColor: MoonColors.accent.withValues(alpha: tv ? 0.24 : 0.16),
    hoverColor: Colors.white.withValues(alpha: 0.06),
    dividerColor: MoonColors.line,
    iconTheme: const IconThemeData(color: MoonColors.muted, size: 22),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.045),
      hintStyle: const TextStyle(color: MoonColors.faint, fontSize: 14),
      labelStyle: const TextStyle(color: MoonColors.muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MoonColors.accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MoonColors.danger),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return MoonColors.accent.withValues(alpha: tv ? 0.3 : 0.18);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return null;
        }),
        side: tv
            ? WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return const BorderSide(
                    color: MoonColors.accentStrong,
                    width: 1.5,
                  );
                }
                return BorderSide.none;
              })
            : null,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            backgroundColor: MoonColors.accent,
            foregroundColor: const Color(0xFF03141D),
            disabledBackgroundColor: MoonColors.accent.withValues(alpha: 0.2),
            disabledForegroundColor: MoonColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ).copyWith(
            side: tv
                ? WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.focused)) {
                      return const BorderSide(color: Colors.white, width: 2);
                    }
                    return BorderSide.none;
                  })
                : null,
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: MoonColors.text,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ).copyWith(
            side: tv
                ? WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.focused)) {
                      return const BorderSide(
                        color: MoonColors.accentStrong,
                        width: 2,
                      );
                    }
                    return BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    );
                  })
                : null,
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style:
          TextButton.styleFrom(
            foregroundColor: MoonColors.accent,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ).copyWith(
            side: tv
                ? WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.focused)) {
                      return const BorderSide(
                        color: MoonColors.accentStrong,
                        width: 1.5,
                      );
                    }
                    return BorderSide.none;
                  })
                : null,
          ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white.withValues(alpha: 0.045),
      selectedColor: MoonColors.accent.withValues(alpha: 0.16),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
      labelStyle: const TextStyle(
        color: MoonColors.muted,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: MoonColors.accentStrong,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: MoonColors.surface2,
      contentTextStyle: const TextStyle(color: MoonColors.text, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MoonColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MoonColors.surface,
      modalBackgroundColor: MoonColors.surface,
      showDragHandle: true,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: MoonColors.accent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.16)),
      radius: const Radius.circular(4),
      thickness: const WidgetStatePropertyAll(5),
    ),
  );
}

class MoonBackdrop extends StatelessWidget {
  const MoonBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF060A13), Color(0xFF0A1220), Color(0xFF0D1729)],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        Positioned(
          top: -260,
          right: -160,
          child: IgnorePointer(
            child: Container(
              width: 720,
              height: 720,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MoonColors.accent.withValues(alpha: 0.14),
                    MoonColors.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -320,
          left: -220,
          child: IgnorePointer(
            child: Container(
              width: 760,
              height: 760,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MoonColors.violet.withValues(alpha: 0.12),
                    MoonColors.violet.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _StarPainter())),
        ),
        child,
      ],
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.035);
    const points = <Offset>[
      Offset(0.08, 0.16),
      Offset(0.15, 0.62),
      Offset(0.26, 0.28),
      Offset(0.36, 0.86),
      Offset(0.47, 0.12),
      Offset(0.58, 0.48),
      Offset(0.69, 0.74),
      Offset(0.78, 0.22),
      Offset(0.88, 0.58),
      Offset(0.94, 0.36),
      Offset(0.53, 0.94),
      Offset(0.32, 0.52),
    ];
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        i.isEven ? 1.2 : 0.8,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.onTap,
    this.borderColor,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: color == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.065),
                  Colors.white.withValues(alpha: 0.025),
                ],
              )
            : null,
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

class MoonLogo extends StatelessWidget {
  const MoonLogo({super.key, this.compact = false, this.size = 38});

  final bool compact;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo_mark.png',
          width: size,
          height: size,
          filterQuality: FilterQuality.high,
        ),
        if (!compact) ...[
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MoonTV',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 20, letterSpacing: -0.5),
              ),
              Text(
                'MEDIA & SOURCES',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: MoonColors.faint,
                  fontSize: 8.5,
                  letterSpacing: 2.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = MoonColors.accent});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        letterSpacing: 2.0,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AccentPill extends StatelessWidget {
  const AccentPill({
    super.key,
    required this.label,
    this.icon,
    this.color = MoonColors.accent,
    this.filled = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: filled
              ? color.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: filled ? color : MoonColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: child,
    );
  }
}

class SourceGlyph extends StatelessWidget {
  const SourceGlyph({
    super.key,
    required this.name,
    this.size = 38,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cleaned = name.replaceAll(RegExp(r'[^\u4e00-\u9fa5A-Za-z0-9]'), '');
    final letter = cleaned.isEmpty ? 'M' : cleaned.substring(0, 1);
    final palette = [
      MoonColors.accent,
      MoonColors.violet,
      MoonColors.gold,
      MoonColors.success,
      const Color(0xFFFF9D7A),
    ];
    final tint = color ?? palette[name.hashCode.abs() % palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint.withValues(alpha: 0.28), tint.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: tint,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: GlassCard(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: MoonColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: MoonColors.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(icon, color: MoonColors.accent, size: 27),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: MoonColors.danger.withValues(alpha: 0.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: MoonColors.danger,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: MoonColors.text),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = '正在连接源'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(height: 16),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class FocusableSurface extends StatefulWidget {
  const FocusableSurface({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 18,
    this.padding = EdgeInsets.zero,
    this.borderColor,
    this.focusedBorderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? focusedBorderColor;

  @override
  State<FocusableSurface> createState() => _FocusableSurfaceState();
}

class _FocusableSurfaceState extends State<FocusableSurface> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _focused
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: _focused
                ? (widget.focusedBorderColor ?? MoonColors.accent)
                : (widget.borderColor ?? Colors.white.withValues(alpha: 0.07)),
            width: _focused ? 1.6 : 1,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: MoonColors.accent.withValues(alpha: 0.16),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.radius),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Crops/blurs a remote image into a soft backdrop. Keeps the detail page
/// readable even when a source returns a low-resolution poster.
class ImageBackdrop extends StatelessWidget {
  const ImageBackdrop({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [MoonColors.surface2, MoonColors.background],
          ),
        ),
        child: SizedBox.expand(),
      );
    }
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: MoonColors.surface,
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
