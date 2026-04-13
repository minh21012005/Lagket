import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final IconData? icon;
  final double? height;
  final double borderRadius;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
    this.height = 54,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: _foreground),
                const SizedBox(width: 8),
              ],
              Text(label, style: AppTextStyles.buttonText.copyWith(color: _foreground)),
            ],
          );

    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: _buildButton(child),
      ),
    );
  }

  Widget _buildButton(Widget child) {
    if (variant == AppButtonVariant.ghost) {
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: child,
      );
    }

    if (variant == AppButtonVariant.secondary) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border, width: 1.5),
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: variant == AppButtonVariant.danger
            ? AppColors.error
            : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: child,
    );
  }

  Color get _foreground {
    switch (variant) {
      case AppButtonVariant.ghost:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.textPrimary;
      case AppButtonVariant.danger:
        return Colors.white;
      case AppButtonVariant.primary:
        return Colors.white;
    }
  }
}
