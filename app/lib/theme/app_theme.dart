import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The kalamkari-derived color system from BRANDING.md sec 2. Every
/// token is named in Telugu on purpose -- see that doc's sec 1: the
/// design system and the curriculum are meant to be the same object.
///
/// Contrast notes (verified in BRANDING.md): raw [pasupu] and [kamala]
/// are fills only (3.45:1 / 3.19:1) -- always use the `*Text` variants
/// for text, which clear AA. [pacha]/[erra] are reserved for answer
/// states; using them decoratively elsewhere destroys the signal at the
/// exact moment it matters (BRANDING sec 2).
class AppColors {
  AppColors._();

  // నీలం (neelam) -- primary ink. Body text, icon ground, nav.
  static const neelamLight = Color(0xFF21464C);
  static const neelamDark = Color(0xFFF3E7D6);

  // పసుపు (pasupu) -- turmeric. Progress, streak, earned things.
  static const pasupuLight = Color(0xFFB17A28);
  static const pasupuTextLight = Color(0xFF8A5D1B);
  static const pasupuDark = Color(0xFFE0A94B);

  // కమలా రంగు (kamala) -- orange. The single CTA color, one per screen.
  static const kamalaLight = Color(0xFFDB6B29);
  static const kamalaTextLight = Color(0xFFB4501A);
  static const kamalaDark = Color(0xFFF08A4B);

  // తెల్ల (thella) -- ground. Paper, not screen.
  static const thellaGroundLight = Color(0xFFFEF6EB);
  static const thellaSurfaceLight = Color(0xFFFBEEDD);
  static const thellaGroundDark = Color(0xFF101F23);
  static const thellaSurfaceDark = Color(0xFF182E33);

  // పచ్చ (pacha) -- green. Correct. Semantic only, never decorative.
  static const pachaLight = Color(0xFF3F7A4B);
  static const pachaDark = Color(0xFF7BC08C);

  // ఎర్ర (erra) -- red. Not-yet. Hairline weight, never a filled block.
  static const erraLight = Color(0xFFB3402B);
  static const erraDark = Color(0xFFF08877);
}

class AppTheme {
  AppTheme._();

  /// BRANDING sec 3's Anek Latin, used for all Latin UI text. Anek
  /// Telugu belongs to [TeluguText] instead of the ambient theme, since
  /// it also carries the 1.08x sizing rule that only applies to Telugu
  /// script, never to Latin transliteration or English chrome.
  static TextTheme _textTheme(Color ink) {
    final base = GoogleFonts.anekLatinTextTheme();
    return base
        .apply(bodyColor: ink, displayColor: ink)
        .copyWith(
          // BRANDING sec 3 scale (1.25 ratio off a 16px base).
          headlineMedium: GoogleFonts.anekLatin(fontSize: 25, height: 1.25, fontWeight: FontWeight.w800, color: ink),
          titleLarge: GoogleFonts.anekLatin(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, color: ink),
          bodyLarge: GoogleFonts.anekLatin(fontSize: 16, height: 1.6, color: ink),
          bodySmall: GoogleFonts.anekLatin(fontSize: 13, height: 1.5, color: ink.withValues(alpha: 0.7)),
        );
  }

  static ThemeData light() => _build(
        brightness: Brightness.light,
        ink: AppColors.neelamLight,
        ground: AppColors.thellaGroundLight,
        surface: AppColors.thellaSurfaceLight,
        cta: AppColors.kamalaLight,
        ctaText: AppColors.kamalaTextLight,
        pasupu: AppColors.pasupuLight,
        pacha: AppColors.pachaLight,
        erra: AppColors.erraLight,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        ink: AppColors.neelamDark,
        ground: AppColors.thellaGroundDark,
        surface: AppColors.thellaSurfaceDark,
        cta: AppColors.kamalaDark,
        ctaText: AppColors.kamalaDark,
        pasupu: AppColors.pasupuDark,
        pacha: AppColors.pachaDark,
        erra: AppColors.erraDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color ink,
    required Color ground,
    required Color surface,
    required Color cta,
    required Color ctaText,
    required Color pasupu,
    required Color pacha,
    required Color erra,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: cta,
      onPrimary: brightness == Brightness.dark ? AppColors.thellaGroundDark : Colors.white,
      secondary: pasupu,
      onSecondary: brightness == Brightness.dark ? AppColors.thellaGroundDark : Colors.white,
      error: erra,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ground,
      textTheme: _textTheme(ink),
      appBarTheme: AppBarTheme(
        backgroundColor: ground,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.anekLatin(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: cta, linearTrackColor: surface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cta,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.anekLatin(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: ink.withValues(alpha: 0.25)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.anekLatin(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      iconTheme: IconThemeData(color: ink),
      dividerColor: ink.withValues(alpha: 0.12),
      extensions: [AppSemanticColors(pacha: pacha, erra: erra, ctaText: ctaText)],
    );
  }
}

/// Answer-state colors kept off [ColorScheme] on purpose -- BRANDING sec 2
/// reserves pacha/erra for correct/not-yet only, and a ThemeExtension is
/// how call sites reach them without reaching for [Colors.green] instead
/// (which is what the pre-brand UI did).
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color pacha;
  final Color erra;
  final Color ctaText;

  const AppSemanticColors({required this.pacha, required this.erra, required this.ctaText});

  @override
  AppSemanticColors copyWith({Color? pacha, Color? erra, Color? ctaText}) => AppSemanticColors(
        pacha: pacha ?? this.pacha,
        erra: erra ?? this.erra,
        ctaText: ctaText ?? this.ctaText,
      );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      pacha: Color.lerp(pacha, other.pacha, t)!,
      erra: Color.lerp(erra, other.erra, t)!,
      ctaText: Color.lerp(ctaText, other.ctaText, t)!,
    );
  }
}

/// Renders Telugu script at BRANDING sec 3's 1.08x rule: Telugu is set
/// at 1.08x the Latin size at every step to compensate for its smaller
/// effective x-height. Baking this into one widget -- rather than tuning
/// it per screen -- is the doc's explicit instruction.
class TeluguText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const TeluguText(this.text, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final scaledSize = (base.fontSize ?? 16) * 1.08;
    return Text(
      text,
      textAlign: textAlign,
      style: GoogleFonts.anekTelugu(textStyle: base, fontSize: scaledSize),
    );
  }
}
