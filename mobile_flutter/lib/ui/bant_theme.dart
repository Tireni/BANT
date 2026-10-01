import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class BantPalette extends ThemeExtension<BantPalette> {
  final Color background;
  final Color surface;
  final Color soft;
  final Color blue;
  final Color blueDark;
  final Color mint;
  final Color mintSoft;
  final Color text;
  final Color secondary;
  final Color muted;
  final Color border;
  final Color danger;
  final Color warning;
  final Color purple;

  const BantPalette({
    required this.background,
    required this.surface,
    required this.soft,
    required this.blue,
    required this.blueDark,
    required this.mint,
    required this.mintSoft,
    required this.text,
    required this.secondary,
    required this.muted,
    required this.border,
    required this.danger,
    required this.warning,
    required this.purple,
  });

  @override
  BantPalette copyWith({
    Color? background,
    Color? surface,
    Color? soft,
    Color? blue,
    Color? blueDark,
    Color? mint,
    Color? mintSoft,
    Color? text,
    Color? secondary,
    Color? muted,
    Color? border,
    Color? danger,
    Color? warning,
    Color? purple,
  }) => BantPalette(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        soft: soft ?? this.soft,
        blue: blue ?? this.blue,
        blueDark: blueDark ?? this.blueDark,
        mint: mint ?? this.mint,
        mintSoft: mintSoft ?? this.mintSoft,
        text: text ?? this.text,
        secondary: secondary ?? this.secondary,
        muted: muted ?? this.muted,
        border: border ?? this.border,
        danger: danger ?? this.danger,
        warning: warning ?? this.warning,
        purple: purple ?? this.purple,
      );

  @override
  BantPalette lerp(ThemeExtension<BantPalette>? other, double t) {
    if (other is! BantPalette) return this;
    return BantPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      blueDark: Color.lerp(blueDark, other.blueDark, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      mintSoft: Color.lerp(mintSoft, other.mintSoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
    );
  }
}

class BantTheme {
  // Launch/light constants retained for older widgets while parity screens use of(context).
  static const blue = Color(0xFF0E96F6);
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const text = Color(0xFF172033);
  static const secondary = Color(0xFF667085);
  static const border = Color(0xFFE4E7EC);
  static const mint = Color(0xFF43D88B);
  static const danger = Color(0xFFF04438);

  static const lightPalette = BantPalette(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    soft: Color(0xFFF1F5F9),
    blue: Color(0xFF0E96F6),
    blueDark: Color(0xFF087BD1),
    mint: Color(0xFF43D88B),
    mintSoft: Color(0xFFDDF9EB),
    text: Color(0xFF172033),
    secondary: Color(0xFF667085),
    muted: Color(0xFF98A2B3),
    border: Color(0xFFE4E7EC),
    danger: Color(0xFFF04438),
    warning: Color(0xFFF79009),
    purple: Color(0xFF8B5CF6),
  );

  static const darkPalette = BantPalette(
    background: Color(0xFF0D1117),
    surface: Color(0xFF151B23),
    soft: Color(0xFF1D2530),
    blue: Color(0xFF22A3FF),
    blueDark: Color(0xFF0E96F6),
    mint: Color(0xFF4CE09A),
    mintSoft: Color(0xFF143C2B),
    text: Color(0xFFF8FAFC),
    secondary: Color(0xFFB8C2CF),
    muted: Color(0xFF7D8998),
    border: Color(0xFF2A3441),
    danger: Color(0xFFFF6B61),
    warning: Color(0xFFF79009),
    purple: Color(0xFFA78BFA),
  );

  static BantPalette of(BuildContext context) =>
      Theme.of(context).extension<BantPalette>() ?? lightPalette;

  static ThemeData light() => _build(lightPalette, Brightness.light);
  static ThemeData dark() => _build(darkPalette, Brightness.dark);

  static ThemeData _build(BantPalette colors, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.blue,
        brightness: brightness,
        primary: colors.blue,
        secondary: colors.mint,
        surface: colors.surface,
        error: colors.danger,
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: colors.text,
      displayColor: colors.text,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(base.primaryTextTheme),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: colors.surface,
        indicatorColor: colors.soft,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.secondary,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: GoogleFonts.plusJakartaSans(color: colors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.blue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dividerColor: colors.border,
      cardColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.text,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: colors.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: brightness,
          systemNavigationBarColor: colors.surface,
          systemNavigationBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
      ),
    );
  }
}
