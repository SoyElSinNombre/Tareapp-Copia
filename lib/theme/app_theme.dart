import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta "académica": navy profundo + dorado (como un sello o insignia
/// universitaria), sobre un fondo cálido tipo papel. Se usa en toda la
/// app en vez de los colores por defecto de Material, para que se
/// sienta como una identidad propia y no como una plantilla genérica.
class AppColors {
  static const navy = Color(0xFF1F2D50);
  static const navyDeep = Color(0xFF12172B);
  static const gold = Color(0xFFB8862B);
  static const goldLight = Color(0xFFD9B871);
  static const parchment = Color(0xFFF7F3EA);
  static const maroon = Color(0xFF8C2F39);
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final base = GoogleFonts.interTextTheme(
      brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );
    // Los títulos usan una serif (Lora) para el toque "académico"; el
    // cuerpo de texto se queda en una sans limpia (Inter) para que siga
    // siendo fácil de leer en listas largas.
    return base.copyWith(
      headlineSmall: GoogleFonts.lora(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      titleLarge: GoogleFonts.lora(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.lora(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.lora(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: Brightness.light,
    ).copyWith(
      secondary: AppColors.gold,
      error: AppColors.maroon,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.parchment,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.navy.withValues(alpha: 0.08)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.gold.withValues(alpha: 0.22),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyDeep,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.navy.withValues(alpha: 0.2)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: AppColors.goldLight,
      error: const Color(0xFFCF6679),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.navyDeep,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navyDeep,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.goldLight,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.goldLight,
        foregroundColor: AppColors.navyDeep,
      ),
    );
  }
}
