import 'package:flutter/material.dart';
import '../harmony_colors.dart';
import '../harmony_theme.dart';
import '../harmony_typography.dart';

class HmosChip extends StatelessWidget {
  const HmosChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? HmosColors.primary : HmosColors.surface,
          borderRadius: BorderRadius.circular(HmosTheme.radiusFull),
          border: Border.all(color: selected ? HmosColors.primary : HmosColors.divider),
          boxShadow: selected ? [BoxShadow(color: HmosColors.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : HmosColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: HmosTypography.labelSmall.copyWith(color: selected ? Colors.white : HmosColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class HmosFilter {
  const HmosFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}

class HmosFilterChips extends StatelessWidget {
  const HmosFilterChips({super.key, required this.filters, required this.selected, required this.onSelect});

  final List<HmosFilter> filters;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(filters.length, (i) {
          final f = filters[i];
          return Padding(
            padding: EdgeInsets.only(right: i == filters.length - 1 ? 0 : 8),
            child: HmosChip(label: f.label, icon: f.icon, selected: i == selected, onTap: () => onSelect(i)),
          );
        }),
      ),
    );
  }
}
