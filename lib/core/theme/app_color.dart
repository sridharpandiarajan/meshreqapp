import 'package:flutter/material.dart';

/// Shared rugged-hardware palette for the whole app: matte gunmetal +
/// olive drab + brick red, styled like a two-way radio or GPS handheld
/// rather than a glowing glass panel. No gradients, no blur shadows --
/// panels read as raised or inset via [Bevel] instead.
///
/// This used to be copy-pasted as a private `_Palette` class into every
/// screen (splash, permission, profile, home). Four copies was the
/// signal to finally pull it out -- update the theme here and every
/// screen picks it up.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF17191C);
  static const panel = Color(0xFF212428);
  static const panelRaised = Color(0xFF272B30);

  static const bevelLight = Color(0xFF3D4147);
  static const bevelDark = Color(0xFF0C0D0F);

  static const olive = Color(0xFF6B7A4F);
  static const oliveDim = Color(0xFF4A5636);
  static const amber = Color(0xFFCC9A35);
  static const amberDim = Color(0xFF8A6A24);
  static const distress = Color(0xFFAE3A2E);
  static const distressDim = Color(0xFF6B241C);

  static const textPrimary = Color(0xFFE1E2E0);
  static const textMuted = Color(0xFF868A8D);
  static const hairline = Color(0xFF34383D);

  static const ledOn = Color(0xFF7A9963);
  static const ledOff = Color(0xFF3C4045);

  // Form-field aliases (emergency profile screen).
  static const fieldFill = panel;
  static const error = distress;
}