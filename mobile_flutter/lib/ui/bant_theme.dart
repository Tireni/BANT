import 'package:flutter/material.dart';

class BantTheme {
  static const blue = Color(0xFF0E96F6);
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const text = Color(0xFF111827);
  static const secondary = Color(0xFF667085);
  static const border = Color(0xFFE4E7EC);
  static const mint = Color(0xFF12B76A);
  static const danger = Color(0xFFF04438);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        fontFamily: 'sans',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: blue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      );
}
