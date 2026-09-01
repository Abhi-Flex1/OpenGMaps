import 'package:flutter/material.dart';
import '../harmony_colors.dart';
import '../harmony_typography.dart';

class HmosListTile extends StatelessWidget {
  const HmosListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: HmosColors.primaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: leading),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HmosTypography.titleSmall.copyWith(fontSize: 15)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: HmosTypography.bodySmall.copyWith(color: HmosColors.textTertiary)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class HmosSectionHeader extends StatelessWidget {
  const HmosSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: HmosTypography.titleSmall.copyWith(color: HmosColors.textSecondary, fontSize: 13, letterSpacing: 0.3)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: HmosTypography.labelSmall.copyWith(color: HmosColors.primary)),
            ),
        ],
      ),
    );
  }
}
