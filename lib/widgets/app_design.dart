import 'morph_icon.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const background = Color(0xFF101412);
  static const surface = Color(0xFF1B211D);
  static const raised = Color(0xFF252D26);
  static const line = Color(0xFF354036);
  static const ink = Color(0xFFF2F3E9);
  static const muted = Color(0xFFA4B0A2);
  static const lime = Color(0xFFD4F58B);
  static const orange = Color(0xFFFFAE83);
  static const red = Color(0xFFFF786A);
}

class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.raised,
    required this.line,
    required this.ink,
    required this.muted,
    required this.lime,
    required this.orange,
    required this.red,
  });
  final Color background, surface, raised, line, ink, muted, lime, orange, red;
  static const dark = AppPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    raised: AppColors.raised,
    line: AppColors.line,
    ink: AppColors.ink,
    muted: AppColors.muted,
    lime: AppColors.lime,
    orange: AppColors.orange,
    red: AppColors.red,
  );
  static const light = AppPalette(
    background: Color(0xFFF5F7F0),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFE8EDE0),
    line: Color(0xFFCFD8C8),
    ink: Color(0xFF1B291F),
    muted: Color(0xFF53624F),
    lime: Color(0xFF3D650D),
    orange: Color(0xFF95501F),
    red: Color(0xFFB32932),
  );
}

extension MotionPalette on BuildContext {
  AppPalette get colors => Theme.of(this).brightness == Brightness.light
      ? AppPalette.light
      : AppPalette.dark;
}

ThemeData buildAppTheme({Brightness brightness = Brightness.dark}) {
  final colors = brightness == Brightness.light
      ? AppPalette.light
      : AppPalette.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.lime,
      brightness: brightness,
      surface: colors.surface,
      primary: colors.lime,
      onPrimary: colors.background,
      onSurface: colors.ink,
      error: colors.red,
    ),
    scaffoldBackgroundColor: colors.background,
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 38,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.8,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, height: 1.5, color: colors.muted),
      labelSmall: TextStyle(
        fontSize: 10,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    ).apply(bodyColor: colors.ink, displayColor: colors.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.ink,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      labelStyle: TextStyle(color: colors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.lime, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? colors.background : colors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? colors.lime : colors.raised,
      ),
      trackOutlineColor: WidgetStatePropertyAll(colors.line),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.lime,
      thumbColor: colors.lime,
      inactiveTrackColor: colors.line,
      trackHeight: 4,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.lime,
      contentTextStyle: TextStyle(color: colors.background),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerColor: colors.line,
  );
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(22),
  });
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? context.colors.surface,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: context.colors.line.withValues(alpha: 0.65)),
    ),
    child: child,
  );
}

/// Tiêu đề màn hình ngắn gọn, cùng phong cách màn Quản trị Motion.
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    this.index = '',
    required this.title,
    required this.description,
  });
  final String index, title, description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18, top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(color: context.colors.muted, height: 1.45),
          ),
        ],
      ],
    ),
  );
}

/// Đổi nhãn viết HOA cũ sang dạng câu cho dễ đọc, giữ nguyên các từ viết tắt.
String sentenceCase(String text) {
  if (text != text.toUpperCase()) return text;
  const keep = {'SOS', 'SIM', 'SMS', 'OTP', 'GPS', 'API', 'XYZ'};
  final words = text.split(' ');
  final out = <String>[];
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    if (keep.contains(word)) {
      out.add(word);
    } else if (word == 'MOTION') {
      out.add('Motion');
    } else {
      final lower = word.toLowerCase();
      out.add(
        i == 0 && lower.isNotEmpty
            ? lower[0].toUpperCase() + lower.substring(1)
            : lower,
      );
    }
  }
  return out.join(' ');
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.trailing});
  final String label;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            sentenceCase(label),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.colors.ink,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(color: context.colors.muted, fontSize: 11),
          ),
      ],
    ),
  );
}

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = AppGlyph.arrowUpRight,
    this.color,
    this.outlined = false,
  });
  final String label;
  final VoidCallback onPressed;
  final AppGlyph icon;
  final Color? color;
  final bool outlined;
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => _pressed = true),
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? 0.965 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: FilledButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          widget.onPressed();
        },
        style: FilledButton.styleFrom(
          foregroundColor: widget.outlined
              ? (widget.color ?? context.colors.lime)
              : context.colors.background,
          backgroundColor: widget.outlined
              ? context.colors.surface
              : (widget.color ?? context.colors.lime),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          minimumSize: const Size(double.infinity, 62),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: widget.outlined
                ? BorderSide(color: context.colors.line)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            MorphIcon(
              widget.icon,
              alternate: widget.icon.pressAlternate,
              active: _pressed,
              size: 23,
            ),
          ],
        ),
      ),
    ),
  );
}

class NoteLine extends StatelessWidget {
  const NoteLine(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.only(top: 3),
        child: MorphIcon(AppGlyph.info, size: 15, color: context.colors.muted),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: context.colors.muted,
          ),
        ),
      ),
    ],
  );
}
