import 'package:flutter/material.dart';
import '../harmony_colors.dart';
import '../harmony_theme.dart';
import '../harmony_typography.dart';

/// HarmonyOS AppBar — centered title, no elevation, optional blur
class HmosAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HmosAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: HmosTypography.titleMedium),
          if (subtitle != null)
            Text(
              subtitle!,
              style: HmosTypography.bodySmall.copyWith(color: HmosColors.textTertiary),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: HmosColors.divider.withOpacity(0.6)),
      ),
    );
  }
}

/// HarmonyOS SliverAppBar variant for map screen
class HmosSliverAppBar extends StatelessWidget {
  const HmosSliverAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: HmosColors.surface.withOpacity(0.9),
      elevation: 0,
      centerTitle: true,
      title: Text(title, style: HmosTypography.titleMedium),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: HmosColors.divider),
      ),
    );
  }
}

/// HarmonyOS bottom navigation — pill shaped, floating
class HmosBottomBar extends StatelessWidget {
  const HmosBottomBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: HmosColors.surface,
        borderRadius: BorderRadius.circular(HmosTheme.radiusXLarge),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: HmosColors.divider.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(context, 0, Icons.map_outlined, Icons.map, 'Explore'),
          _item(context, 1, Icons.bookmark_border, Icons.bookmark, 'Saved'),
          _item(context, 2, Icons.person_outline, Icons.person, 'You'),
        ],
      ),
    );
  }

  Widget _item(BuildContext ctx, int idx, IconData outline, IconData filled, String label) {
    final selected = idx == currentIndex;
    return GestureDetector(
      onTap: () => onTap(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? HmosColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(HmosTheme.radiusFull),
        ),
        child: Row(
          children: [
            Icon(selected ? filled : outline, size: 22, color: selected ? HmosColors.primary : HmosColors.textTertiary),
            if (selected) ...[
              const SizedBox(width: 8),
              Text(label, style: HmosTypography.labelLarge.copyWith(color: HmosColors.primary, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
