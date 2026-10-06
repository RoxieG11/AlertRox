import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? color;
  final Border? border;
  final Clip clipBehavior;
  final ShapeBorder? shape;
  final double? elevation;

  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius,
    this.color,
    this.border,
    this.clipBehavior = Clip.none,
    this.shape,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!provider.glassmorphicMode) {
      return Card(
        margin: margin,
        color: color,
        clipBehavior: clipBehavior,
        elevation: elevation,
        shape: shape ??
            (borderRadius != null
                ? RoundedRectangleBorder(borderRadius: borderRadius!)
                : null),
        child:
            padding != null ? Padding(padding: padding!, child: child) : child,
      );
    }

    final effectiveRadius = borderRadius ??
        (shape is RoundedRectangleBorder
            ? (shape as RoundedRectangleBorder)
                .borderRadius
                .resolve(Directionality.of(context))
            : BorderRadius.circular(16));

    final effectiveBg = (color != null && color!.a < 0.9)
        ? color!
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.55));

    final effectiveBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.35),
          width: 1.0,
        );

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    Widget result = ClipRRect(
      borderRadius: effectiveRadius,
      clipBehavior: clipBehavior != Clip.none ? clipBehavior : Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: effectiveRadius,
          border: effectiveBorder,
        ),
        child: content,
      ),
    );

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }

    return result;
  }
}
