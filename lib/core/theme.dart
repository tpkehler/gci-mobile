import 'package:flutter/material.dart';

/// Jam brand theme (Brand Sheet v0.2): teal is the default — brand, UI, type,
/// the resting field. Amber is *earned*: only the moment of coherence.
class GciTheme {
  GciTheme._();

  /// Teal — the resting field. Primary brand accent.
  static const Color brandTeal = Color(0xFF74B3AA);

  /// Light teal — the bright coherent center.
  static const Color brandTealLight = Color(0xFFA8D6CE);

  /// Deep teal — mid ring / rim voices.
  static const Color brandTealDeep = Color(0xFF5C8B84);

  /// Amber — earned coherence. Convergence moments only; never body or UI.
  static const Color brandAmber = Color(0xFFF0C079);

  /// Charcoal — the resting surface.
  static const Color brandCharcoal = Color(0xFF26282D);

  /// Ink — the deepest field (splash / hero background).
  static const Color brandInk = Color(0xFF1C1E22);

  /// Back-compat alias for the dark brand background (now Ink).
  static const Color brandDark = brandInk;

  static const Color primary = brandTeal;
  static const Color primaryLight = brandTealLight;

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandTeal, brandTealLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandTeal,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
