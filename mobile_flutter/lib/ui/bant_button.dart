import 'package:flutter/material.dart';

import 'bant_theme.dart';

enum BantButtonVariant {
  primary,
  secondary,
  ghost,
  danger,
}

class BantButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Legacy compatibility: previous Flutter screens used secondary=true for
  /// outlined/ghost actions. New parity code should use [variant].
  final bool secondary;
  final BantButtonVariant? variant;

  const BantButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.secondary = false,
    this.variant,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BantTheme.of(context);
    final resolved = variant ??
        (secondary ? BantButtonVariant.ghost : BantButtonVariant.primary);

    final background = switch (resolved) {
      BantButtonVariant.primary => colors.blue,
      BantButtonVariant.secondary => colors.mint,
      BantButtonVariant.ghost => colors.soft,
      BantButtonVariant.danger => colors.danger,
    };

    final foreground = switch (resolved) {
      BantButtonVariant.ghost => colors.blue,
      _ => Colors.white,
    };

    final border = resolved == BantButtonVariant.ghost
        ? BorderSide(color: colors.border)
        : BorderSide.none;

    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: colors.soft,
          disabledForegroundColor: colors.muted,
          side: border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: resolved == BantButtonVariant.ghost
                      ? colors.blue
                      : Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
