import 'package:flutter/material.dart';

class AppTheme {
  static const Color _primary = Color(0xFF6366F1);

  // Light palette
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightBackground = Color(0xFFF5F5F7);
  static const Color _lightBorder = Color(0xFFE5E5E5);
  static const Color _lightTextPrimary = Color(0xFF111827);
  static const Color _lightTextSecondary = Color(0xFF6B7280);

  // Dark palette
  static const Color _darkSurface = Color(0xFF1A1A2E);
  static const Color _darkBackground = Color(0xFF0F0F1A);
  static const Color _darkBorder = Color(0xFF2A2A3E);
  static const Color _darkTextPrimary = Color(0xFFF1F5F9);
  static const Color _darkTextSecondary = Color(0xFF94A3B8);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: _primary,
          surface: _lightSurface,
          onSurface: _lightTextPrimary,
          onPrimary: Colors.white,
          secondary: _lightTextSecondary,
          outline: _lightBorder,
        ),
        scaffoldBackgroundColor: _lightBackground,
        cardTheme: CardTheme(
          color: _lightSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: _lightBorder),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: _lightBorder,
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _lightSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _primary),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: _lightTextPrimary, fontSize: 13),
          bodySmall: TextStyle(color: _lightTextSecondary, fontSize: 12),
          titleMedium: TextStyle(
              color: _lightTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600),
          titleSmall: TextStyle(
              color: _lightTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500),
          labelSmall: TextStyle(color: _lightTextSecondary, fontSize: 11),
        ),
        extensions: const [
          AppColors(
            surface: _lightSurface,
            background: _lightBackground,
            border: _lightBorder,
            textPrimary: _lightTextPrimary,
            textSecondary: _lightTextSecondary,
          ),
        ],
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: _primary,
          surface: _darkSurface,
          onSurface: _darkTextPrimary,
          onPrimary: Colors.white,
          secondary: _darkTextSecondary,
          outline: _darkBorder,
        ),
        scaffoldBackgroundColor: _darkBackground,
        cardTheme: CardTheme(
          color: _darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: _darkBorder),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: _darkBorder,
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _darkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _primary),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: _darkTextPrimary, fontSize: 13),
          bodySmall: TextStyle(color: _darkTextSecondary, fontSize: 12),
          titleMedium: TextStyle(
              color: _darkTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600),
          titleSmall: TextStyle(
              color: _darkTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500),
          labelSmall: TextStyle(color: _darkTextSecondary, fontSize: 11),
        ),
        extensions: const [
          AppColors(
            surface: _darkSurface,
            background: _darkBackground,
            border: _darkBorder,
            textPrimary: _darkTextPrimary,
            textSecondary: _darkTextSecondary,
          ),
        ],
      );
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color surface;
  final Color background;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const AppColors({
    required this.surface,
    required this.background,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  AppColors copyWith({
    Color? surface,
    Color? background,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      background: background ?? this.background,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface: Color.lerp(surface, other.surface, t)!,
      background: Color.lerp(background, other.background, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}
