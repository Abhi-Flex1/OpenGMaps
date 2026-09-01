import 'package:flutter/material.dart';
import '../harmony_colors.dart';
import '../harmony_theme.dart';
import '../harmony_typography.dart';

/// HarmonyOS Search Bar — pill, inner shadow, leading icon, clear
class HmosSearchBar extends StatelessWidget {
  const HmosSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search here',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onTap,
    this.readOnly = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onTap;
  final bool readOnly;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: HmosColors.surfaceVariant,
        borderRadius: BorderRadius.circular(HmosTheme.radiusFull),
        border: Border.all(color: HmosColors.divider.withOpacity(0.0)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search, size: 22, color: HmosColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: HmosTypography.bodyLarge.copyWith(fontSize: 15),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: HmosTypography.bodyMedium.copyWith(color: HmosColors.textTertiary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: HmosColors.textTertiary.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: HmosColors.textTertiary),
              ),
            )
          else
            const SizedBox(width: 8),
          Container(
            width: 1,
            height: 24,
            color: HmosColors.divider,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(color: HmosColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.mic, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// HarmonyOS Search Field — compact variant for bottom sheet
class HmosSearchField extends StatelessWidget {
  const HmosSearchField({super.key, required this.controller, this.hintText = 'Search', this.onChanged});

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: HmosTypography.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: HmosColors.surfaceVariant,
      ),
    );
  }
}
