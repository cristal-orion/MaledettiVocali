/* Hallmark · genre: atmospheric · macrostructure: app-shell (Flutter)
 * anchor hue: neon cyan (#00D9FF) on deep navy · accent-2: violet (#7B61FF)
 * tone: dark · technical · irreverent — tokens locked, no inline magic colors
 */
import 'package:flutter/material.dart';

/// Palette — un'unica fonte di verità per i colori dell'app.
class AppColors {
  AppColors._();

  // Superfici (dal più profondo al più sollevato)
  static const Color abyss = Color(0xFF101626); // fondo del gradiente
  static const Color bg = Color(0xFF1A1A2E); // sfondo base
  static const Color surface = Color(0xFF16213E); // card
  static const Color surfaceHi = Color(0xFF1E2A4A); // card sollevata / hover

  // Accenti
  static const Color accent = Color(0xFF00D9FF); // cyan neon
  static const Color accent2 = Color(0xFF7B61FF); // violet (riassunto)
  static const Color danger = Color(0xFFFF6B6B);

  // Testo (su superfici scure)
  static const Color textHi = Color(0xFFF1F4FF);
  static const Color textMd = Color(0xCCFFFFFF); // ~80%
  static const Color textLo = Color(0x8AFFFFFF); // ~54%
  static const Color textFaint = Color(0x61FFFFFF); // ~38%
  static const Color hairline = Color(0x1FFFFFFF); // ~12% — bordi sottili

  // Gradienti
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bg, abyss],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accent, accent2],
  );
}

/// Scala di spaziatura (passo 4pt).
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;
}

/// Raggi di curvatura coerenti.
class AppRadii {
  AppRadii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

/// Durate animazioni.
class AppMotion {
  AppMotion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
}

/// Scala tipografica (font di sistema, pesi e tracking curati).
class AppText {
  AppText._();

  static const TextStyle display = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textHi,
    letterSpacing: -0.5,
    height: 1.12,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textHi,
    letterSpacing: -0.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textHi,
    height: 1.6,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textMd,
    height: 1.55,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: AppColors.accent,
    letterSpacing: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textFaint,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );
}

/// Tema globale dark — i valori qui si propagano a tutte le schermate.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const base = ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: AppColors.bg,
      onSurface: AppColors.textHi,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.accent,
      splashColor: AppColors.accent.withOpacity(0.08),
      highlightColor: AppColors.accent.withOpacity(0.05),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.title,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHi,
        contentTextStyle: const TextStyle(color: AppColors.textHi),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.bg,
          textStyle: AppText.button,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
