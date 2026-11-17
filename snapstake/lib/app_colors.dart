import 'package:flutter/material.dart';

class AppColors {
  // Branding - SnapStake inspired theme
  static const primary = Color(0xFFFF6B3D); // SnapStake Orange
  static const secondary = Color(0xFF00D4AA); // Teal/Cyan accent

  // States
  static const success = Color(0xFF00D4AA);
  static const warning = Color(0xFFFF6B3D);
  static const warningLight = Color(0xFFFFE8E0);
  static const error = Color(0xFFFF4757);
  static const info = Color(0xFF00D4AA);
  static const infoLight = Color(0xFFE0FFF9);

  // Text
  static const text = Color(0xFFFFFFFF); // White text for dark theme
  static const textLight = Color(0xFFB3B3B3); // Light gray
  static const textDisabled = Color(0xFF666666);

  // Backgrounds
  static const background = Color(0xFF0A0A0A); // Very dark background
  static const cardBackground = Color(0xFF1E1E1E); // Card background
  static const dark = Color(0xFF1A1A1A); // Slightly lighter dark

  // Enhanced gradients
  static const gradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Background gradient for more visual interest - SnapStake inspired
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF252525), // Lighter charcoal at top
      Color(0xFF1A1A1A), // Medium dark
      Color(0xFF0F0F0F), // Main background
      Color(0xFF0A0A0A), // Darker
      Color(0xFF050505), // Deepest black at bottom
    ],
    stops: [0.0, 0.2, 0.5, 0.8, 1.0],
  );

  // Primary glow layer - orange warmth from top-right
  static const subtleGlowGradient = RadialGradient(
    center: Alignment.topRight,
    radius: 3.0,
    colors: [
      Color(0x20FF6B3D), // Stronger orange glow at center
      Color(0x15FF6B3D), // Medium orange
      Color(0x0AFF6B3D), // Subtle orange
      Color(0x05FF6B3D), // Very subtle orange
      Colors.transparent,
    ],
    stops: [0.0, 0.15, 0.35, 0.6, 1.0],
  );

  // Secondary glow layer - teal coolness from bottom-left
  static const secondaryGlowGradient = RadialGradient(
    center: Alignment.bottomLeft,
    radius: 2.5,
    colors: [
      Color(0x1800D4AA), // Teal glow center
      Color(0x1000D4AA), // Medium teal
      Color(0x0800D4AA), // Subtle teal
      Color(0x04FF6B3D), // Tiny orange blend
      Colors.transparent,
    ],
    stops: [0.0, 0.2, 0.45, 0.7, 1.0],
  );

  // Tertiary accent glow - center spotlight effect
  static const accentGlowGradient = RadialGradient(
    center: Alignment.center,
    radius: 1.2,
    colors: [
      Color(0x08FFFFFF), // Very subtle white center
      Color(0x05FF6B3D), // Hint of orange
      Color(0x0300D4AA), // Hint of teal
      Colors.transparent,
    ],
    stops: [0.0, 0.3, 0.6, 1.0],
  );
}
