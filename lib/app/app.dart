/// The application shell: theme, localisation, and the first screen.
library;

import 'package:flutter/material.dart';

import '../features/family/family_list_screen.dart';
import '../l10n/app_localizations.dart';

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
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
      useMaterial3: true,
    ),
    home: const FamilyListScreen(),
  );
}
