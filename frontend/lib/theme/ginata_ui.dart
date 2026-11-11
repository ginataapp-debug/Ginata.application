import 'package:flutter/material.dart';
import 'ginata_theme.dart';

class GSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
}

class GText {
  static const TextStyle title = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: GinataColors.primary, height: 1.25);
  static const TextStyle cardTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: GinataColors.primary, height: 1.3);
  static const TextStyle body = TextStyle(fontSize: 13, color: GinataColors.textPrimary, height: 1.4);
  static const TextStyle caption = TextStyle(fontSize: 12, color: GinataColors.textSecondary, height: 1.4);
  static const TextStyle label = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GinataColors.textSecondary, letterSpacing: 0.2);
}

enum GStatusTone { success, warning, danger, info, neutral }

class GStatusChip extends StatelessWidget {
  final String label;
  final GStatusTone tone;
  final IconData? icon;

  const GStatusChip({super.key, required this.label, this.tone = GStatusTone.neutral, this.icon});

  (Color, Color) get _colors => switch (tone) {
        GStatusTone.success => (GinataColors.successContainer, GinataColors.successSage),
        GStatusTone.warning => (GinataColors.warningContainer, GinataColors.warningOchre),
        GStatusTone.danger => (GinataColors.errorContainer, GinataColors.alertTerracotta),
        GStatusTone.info => (GinataColors.secondaryContainer, GinataColors.primary),
        GStatusTone.neutral => (GinataColors.surfaceSubdued, GinataColors.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const GSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(GSpace.md),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: GinataColors.surface,
        borderRadius: BorderRadius.circular(GSpace.radiusLg),
        border: Border.all(color: const Color(0x14174A3F)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3))],
      ),
      child: child,
    );
  }
}

class GSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const GSectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: GText.title)),
              if (subtitle != null) ...[
                const SizedBox(height: GSpace.xxs),
                Text(subtitle!, style: GText.caption),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: GSpace.xs), trailing!],
      ],
    );
  }
}

class GEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const GEmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return GSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.lg, vertical: GSpace.xxl),
      child: Column(
        children: [
          Icon(icon, size: 42, color: GinataColors.outline),
          const SizedBox(height: GSpace.sm),
          Text(title, style: GText.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: GSpace.xxs),
          Text(message, style: GText.caption, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: GSpace.md), action!],
        ],
      ),
    );
  }
}

class GErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const GErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GSpace.sm),
      decoration: BoxDecoration(
        color: GinataColors.errorContainer,
        borderRadius: BorderRadius.circular(GSpace.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: GinataColors.alertTerracotta, size: 20),
          const SizedBox(width: GSpace.xs),
          Expanded(child: Text(message, style: GText.body.copyWith(color: GinataColors.alertTerracotta))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class GLoadingState extends StatelessWidget {
  final String? message;

  const GLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: GinataColors.primary),
            if (message != null) ...[
              const SizedBox(height: GSpace.sm),
              Text(message!, style: GText.caption, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class GInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const GInfoRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: GinataColors.secondary),
          const SizedBox(width: GSpace.xs),
          SizedBox(width: 92, child: Text(label, style: GText.label)),
          Expanded(child: Text(value, style: GText.body, softWrap: true)),
        ],
      ),
    );
  }
}
