import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CompactSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final VoidCallback? onClear;

  const CompactSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: onSurface, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(color: colors.textMuted),
          prefixIcon: Icon(Icons.search, color: colors.textMuted),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: colors.textMuted),
                  onPressed: onClear,
                ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
