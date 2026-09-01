import 'package:flutter/material.dart';
import '../harmony_colors.dart';
import '../harmony_theme.dart';
import '../harmony_typography.dart';

enum HmosButtonVariant { primary, secondary, ghost }

class HmosButton extends StatelessWidget {
  const HmosButton({
    super.key,
    required this.label,
    this.icon,
    this.variant = HmosButtonVariant.primary,
    required this.onPressed,
    this.fullWidth = false,
    this.small = false,
  });

  final String label;
  final IconData? icon;
  final HmosButtonVariant variant;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final bool small;

  @override
  Widget build(BuildContext context) {
    ButtonStyle style;
    if (variant == HmosButtonVariant.primary) {
      style = ElevatedButton.styleFrom(
        backgroundColor: HmosColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 24, vertical: small ? 10 : 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HmosTheme.radiusFull)),
        textStyle: HmosTypography.labelLarge.copyWith(color: Colors.white),
      );
    } else if (variant == HmosButtonVariant.secondary) {
      style = ElevatedButton.styleFrom(
        backgroundColor: HmosColors.primaryContainer,
        foregroundColor: HmosColors.primary,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 24, vertical: small ? 10 : 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HmosTheme.radiusFull)),
      );
    } else {
      style = TextButton.styleFrom(
        foregroundColor: HmosColors.primary,
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 24, vertical: small ? 10 : 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HmosTheme.radiusFull)),
      );
    }

    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: small ? 16 : 18), const SizedBox(width: 8)],
        Text(label, style: HmosTypography.labelLarge.copyWith(fontSize: small ? 13 : 14, color: variant == HmosButtonVariant.primary ? Colors.white : null)),
      ],
    );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: variant == HmosButtonVariant.ghost
          ? TextButton(onPressed: onPressed, style: style, child: child)
          : ElevatedButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

class HmosIconButton extends StatelessWidget {
  const HmosIconButton({super.key, required this.icon, required this.onPressed, this.filled = true});

  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? HmosColors.surface : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HmosTheme.radiusFull),
        side: filled ? BorderSide(color: HmosColors.divider.withOpacity(0.5)) : BorderSide.none,
      ),
      elevation: filled ? 2 : 0,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(HmosTheme.radiusFull),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: HmosColors.textPrimary),
        ),
      ),
    );
  }
}

class HmosFAB extends StatelessWidget {
  const HmosFAB({super.key, required this.icon, required this.onPressed, this.label});

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: HmosColors.surface,
        foregroundColor: HmosColors.primary,
        icon: Icon(icon),
        label: Text(label!, style: HmosTypography.labelLarge.copyWith(color: HmosColors.primary)),
      );
    }
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: HmosColors.surface,
      foregroundColor: HmosColors.primary,
      child: Icon(icon),
    );
  }
}
