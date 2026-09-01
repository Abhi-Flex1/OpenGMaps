import 'package:flutter/material.dart';
import '../harmony_colors.dart';
import '../harmony_theme.dart';

class HmosBottomSheet extends StatelessWidget {
  const HmosBottomSheet({super.key, required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: HmosColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(HmosTheme.radiusXLarge)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: HmosColors.dividerStrong, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Flexible(child: child),
        ],
      ),
    );
  }
}

Future<T?> showHmosBottomSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => HmosBottomSheet(child: child),
  );
}
