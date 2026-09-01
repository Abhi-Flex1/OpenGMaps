import 'package:flutter/material.dart';
import '../harmony_colors.dart';
import '../harmony_theme.dart';

/// HarmonyOS Card — soft shadow, 20dp radius, 16 padding
class HmosCard extends StatelessWidget {
  const HmosCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(HmosTheme.radiusLarge),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
        border: Border.all(color: HmosColors.divider.withOpacity(0.5), width: 0.5),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(HmosTheme.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HmosTheme.radiusLarge),
          child: card,
        ),
      );
    }
    return card;
  }
}

/// HarmonyOS Search Card — used for search bar container
class HmosSearchCard extends StatelessWidget {
  const HmosSearchCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HmosColors.surface,
        borderRadius: BorderRadius.circular(HmosTheme.radiusFull),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}
