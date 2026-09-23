/// The application shell: theme, localisation, and the first screen.
library;

import 'package:flutter/material.dart';

import '../features/family/family_list_screen.dart';
import '../l10n/app_localizations.dart';
import 'grouped_list.dart';

/// Wires up localisation and hands off to the first screen.
///
/// Vietnamese and English from the first screen rather than hardcoded strings
/// extracted later (PRODUCT.md §1.1). Vietnamese is the template locale: it is
/// the first audience, and writing the source strings in the language they are
/// read in avoids translating through English.
class FtreeApp extends StatelessWidget {
  const FtreeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppText.of(context).appTitle,
    localizationsDelegates: AppText.localizationsDelegates,
    supportedLocales: AppText.supportedLocales,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: const FamilyListScreen(),
  );

  /// The phone's settings look: a tinted page with cards floating on it, and a
  /// bar that shares the page colour instead of hovering above it.
  ///
  /// Both brightnesses, because the reader's system decides. The palette lives
  /// in [GroupedColors] so the screens and the theme cannot disagree.
  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: GroupedColors.seed,
      brightness: brightness,
    );
    final page = brightness == Brightness.dark
        ? GroupedColors.pageDark
        : GroupedColors.pageLight;

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: page,
      appBarTheme: AppBarTheme(
        backgroundColor: page,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
