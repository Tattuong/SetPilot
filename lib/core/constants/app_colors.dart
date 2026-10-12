import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFED672A);
  static const Color primaryLight = Color(0xFFF4A06A);
  static const Color coral = Color(0xFFED672A);
  static const Color coralSoft = Color(0xFFFFE8CC);
  static const Color clay = Color(0xFFE36B2E);
  static const Color claySoft = Color(0xFFFFF1E6);
  static const Color tileFull = Color(0xFFD5E3CC);
  static const Color tileCut = Color(0xFFF0C09A);
  static const Color ink = Color(0xFF101114);
  static const Color personA = Color(0xFFE6EDF8);
  static const Color personB = Color(0xFFF6C48A);
  static const Color personADot = Color(0xFF3B6FE0);
  static const Color personBDot = Color(0xFFE07A32);

  static const Color accent = primary;
  static const Color success = Color(0xFF16C47F);
  static const Color warning = Color(0xFFF5C542);
  static const Color error = Color(0xFFE5484D);
  static const Color coin = Color(0xFFFFC107);
  static const Color onGold = Color(0xFF3B1408);
  static const Color onPrimary = Colors.white;

  static const Color background = Color(0xFFF5F5F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFBF6);
  static const Color surfaceVariant = Color(0xFFEFEAE0);
  static const Color border = Color(0xFFE4DDD0);

  static const Color textPrimary = Color(0xFF101114);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF8A918C);

  static const Color darkBackground = Color(0xFF141311);
  static const Color darkSurface = Color(0xFF221F1C);
  static const Color darkInk = Color(0xFFE7E2DA);
  static const Color darkTextSecondary = Color(0xFFB7AFA6);
  static const Color darkTextMuted = Color(0xFF8A8178);
  static const Color lightBackground = Color(0xFFF5F5F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF101114);
  static const Color onSurfaceVariant = Color(0xFF5C6B8A);

  static const List<Color> listPalette = [
    Color(0xFFFF2D8A),
    Color(0xFF16C47F),
    Color(0xFFF5C542),
    Color(0xFF7B5CFF),
    Color(0xFF1AA6C9),
    Color(0xFFFF7A45),
  ];

  static Color brand(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color primaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  static Color onPrimaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.onPrimary;
  static Color primaryLightOf(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;
  static Color canvasOf(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color borderOf(BuildContext context) =>
      Theme.of(context).colorScheme.outline;
  static Color inkOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color secondaryInk(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color mutedInk(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextMuted
          : textMuted;

  static Color primarySoftOf(BuildContext context) =>
      Color.lerp(primaryOf(context), surfaceOf(context), 0.78) ??
      primaryLightOf(context);

  static Color listColor(int index) => listPalette[index % listPalette.length];

  static List<BoxShadow> softShadow({double opacity = 0.10}) => [
        BoxShadow(
          color: const Color(0xFF111111).withValues(alpha: opacity),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFED672A), Color(0xFFC84E18)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF4A06A), Color(0xFFED672A)],
  );

  static const LinearGradient gameGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFED672A), Color(0xFFC84E18)],
  );
}
