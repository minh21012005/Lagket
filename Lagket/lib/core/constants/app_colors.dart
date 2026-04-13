import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryDark = Color(0xFFE55A24);
  static const Color primaryLight = Color(0xFFFF8A60);

  // Accent
  static const Color accent = Color(0xFFFFD166);
  static const Color accentPink = Color(0xFFEF476F);

  // Background
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF242424);
  static const Color card = Color(0xFF1E1E1E);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textHint = Color(0xFF666666);

  // Status
  static const Color success = Color(0xFF06D6A0);
  static const Color error = Color(0xFFEF476F);
  static const Color warning = Color(0xFFFFD166);
  static const Color info = Color(0xFF118AB2);

  // Divider / border
  static const Color divider = Color(0xFF2C2C2C);
  static const Color border = Color(0xFF333333);

  // Overlay
  static const Color overlayDark = Color(0xCC000000);
  static const Color overlayLight = Color(0x1AFFFFFF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accentPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient photoOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xDD000000)],
    begin: Alignment.center,
    end: Alignment.bottomCenter,
  );
}
