import 'package:flutter/material.dart';
import 'app_color.dart';

/// MeshResQ ships one designed theme -- the rugged-hardware dark palette
/// used across every screen. There's no light variant yet, so this is
/// exposed only as `darkTheme` and the app is pinned to `ThemeMode.dark`
/// in main.dart rather than following the system setting, which would
/// otherwise fall back to Flutter's default light Material theme on a
/// light-mode device and clash with every hand-themed screen.
///
/// Every screen currently reads colors straight from [AppColors] rather
/// than `Theme.of(context)`, so this mostly sets sane defaults for
/// built-in widgets that don't take explicit styling yet (SnackBar,
/// dialogs, default button/progress-indicator colors if a new screen
/// forgets to style one explicitly).
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.panel,
        primary: AppColors.amber,
        secondary: AppColors.olive,
        error: AppColors.error,
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.black,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerColor: AppColors.hairline,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.amber,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.panelRaised,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}