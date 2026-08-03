/// The iOS grouped-list look, as a handful of small widgets.
///
/// Settings on the phone is the shape a reader already knows: a tinted page,
/// rounded cards floating on it, a coloured glyph then a label then a chevron.
/// Borrowing it means the family tree does not have to teach its own
/// conventions before it can be read.
///
/// Built on Material rather than Cupertino. The application is Material
/// throughout — dialogs, sheets, fields — and swapping frameworks for the sake
/// of a list style would change far more than the style.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../domain/name_search.dart';

/// The page tint and the card colour behind it, per brightness.
///
/// Taken from the system grouped-background pair: the card has to sit visibly
/// on the page without a border, which is what the two-colour arrangement buys.
final class GroupedColors {
  const GroupedColors._();

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Behind everything. The theme sets it as the scaffold colour.
  static const Color pageLight = Color(0xFFF2F2F7);
  static const Color pageDark = Color(0xFF000000);

  static Color page(BuildContext context) =>
      _isDark(context) ? pageDark : pageLight;

  /// The rounded card a group of rows sits on.
  static Color card(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1C1C1E) : Colors.white;

  /// The hairline between rows, inset to start under the label.
  static Color separator(BuildContext context) =>
      _isDark(context) ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);

  /// Muted text: values, headers, footnotes.
  static Color secondaryLabel(BuildContext context) => _isDark(context)
      ? const Color(0xFFEBEBF5).withValues(alpha: 0.6)
      : const Color(0xFF3C3C43).withValues(alpha: 0.6);

  /// The tints used on row icons, kept few so the screens stay quiet.
  static const Color blue = Color(0xFF0A84FF);
  static const Color green = Color(0xFF30D158);
  static const Color teal = Color(0xFF40C8E0);
  static const Color orange = Color(0xFFFF9F0A);
  static const Color pink = Color(0xFFFF375F);
  static const Color purple = Color(0xFFBF5AF2);
  static const Color grey = Color(0xFF8E8E93);
}

/// The small rounded square that carries a row's glyph.
///
/// 29 points with a white icon inside, which is the size the phone uses; a
/// larger one turns a list of names into a list of pictures.
class RowIcon extends StatelessWidget {
  const RowIcon(this.icon, {required this.color, super.key});

  final IconData icon;
  final Color color;

  static const double size = 29;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Icon(icon, size: 18, color: Colors.white),
  );
}

/// A card holding rows, with an optional header above and footnote below.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    required this.children,
    this.header,
    this.footer,
    super.key,
  });

  /// The rows. Separators are drawn between them, not around them.
  final List<Widget> children;

  /// Small muted text above the card.
  ///
  /// Left as written rather than upper-cased: the reference screens carry no
  /// shouting headers, and upper-casing would mangle a translated string.
  final String? header;

  /// Explanatory text below it, in the same muted grey.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: GroupedColors.secondaryLabel(context),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (header case final title?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(title, style: muted),
            ),
          // A Material, not a coloured box: rows are ListTiles, which paint
          // their ink on the nearest Material, and a plain background in
          // between swallows every tap highlight.
          //
          // Clipped, not merely rounded: a row can slide sideways to reveal
          // actions, and without this it slides out over the corners.
          Material(
            color: GroupedColors.card(context),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (index, child) in children.indexed) ...<Widget>[
                  if (index > 0) const _Separator(),
                  child,
                ],
              ],
            ),
          ),
          if (footer case final note?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(note, style: muted),
            ),
        ],
      ),
    );
  }
}

/// The same card, built row by row as the reader scrolls.
///
/// A [GroupedSection] lays out every child at once, which is right for four
/// families and wrong for four thousand people. The card cannot be one
/// decoration around a lazy list — the rows do not exist to be wrapped — so
/// each row carries its own slice of it and only the ends are rounded.
class GroupedSliverSection extends StatelessWidget {
  const GroupedSliverSection({
    required this.itemCount,
    required this.itemBuilder,
    this.header,
    super.key,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final String? header;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SliverToBoxAdapter();

    return SliverMainAxisGroup(
      slivers: <Widget>[
        if (header case final title?)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 18, 32, 7),
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: GroupedColors.secondaryLabel(context),
                ),
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final child = itemBuilder(context, index);
              if (child == null) return null;

              final radius = Radius.circular(10);
              return Material(
                color: GroupedColors.card(context),
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? radius : Radius.zero,
                  bottom: index == itemCount - 1 ? radius : Radius.zero,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (index > 0) const _Separator(),
                    child,
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Inset from the left so it starts under the label, as on the phone.
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 16),
    child: Divider(
      height: 0.5,
      thickness: 0.5,
      color: GroupedColors.separator(context),
    ),
  );
}

/// One tappable row: glyph, label, optional value, chevron.
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    required this.title,
    this.icon,
    this.iconColor = GroupedColors.grey,
    this.leading,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.titleColor,
    super.key,
  });

  final String title;

  /// Drawn in a [RowIcon] unless [leading] replaces it outright.
  final IconData? icon;
  final Color iconColor;
  final Widget? leading;

  /// A second line under the title.
  final String? subtitle;

  /// Muted text at the trailing end, before the chevron.
  final String? value;

  /// Sits before the chevron — an unlink button, a moon, a switch.
  ///
  /// Added to the chevron rather than replacing it: a row that leads somewhere
  /// has to keep saying so, however many other controls it carries.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// A row that goes nowhere should not promise that it does.
  final bool showChevron;

  /// For a destructive row, which is red rather than tinted.
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = GroupedColors.secondaryLabel(context);

    return ListTile(
      leading: leading ?? (icon == null ? null : RowIcon(icon!, color: iconColor)),
      horizontalTitleGap: 12,
      minLeadingWidth: 0,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(color: titleColor),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
      trailing: _tail(context, muted),
      onTap: onTap,
    );
  }

  Widget? _tail(BuildContext context, Color muted) {
    final parts = <Widget>[
      if (value case final shown?)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            shown,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: muted),
          ),
        ),
      ?trailing,
      if (showChevron && onTap != null)
        Icon(Icons.chevron_right, size: 20, color: muted),
    ];

    if (parts.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }
}

/// A recorded value with its label above it, for use inside [FieldRow].
class InfoField extends StatelessWidget {
  const InfoField({
    required this.label,
    required this.value,
    this.note,
    super.key,
  });

  final String label;
  final String value;

  /// A quieter second line — a lunar reading under a Gregorian date.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = GroupedColors.secondaryLabel(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyLarge),
        if (note case final second?)
          Text(
            second,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
      ],
    );
  }
}

/// One or two fields across the width of a card.
///
/// Two short values — a birth year and a death year, a given name and a family
/// name — read better side by side than as two rows of mostly empty space.
class FieldRow extends StatelessWidget {
  const FieldRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (index, child) in children.indexed) ...<Widget>[
          if (index > 0) const SizedBox(width: 16),
          Expanded(child: child),
        ],
      ],
    ),
  );
}

/// The circle at the top of a screen, with a name under it.
class AvatarHeader extends StatelessWidget {
  const AvatarHeader({
    required this.initials,
    this.title,
    this.subtitle,
    this.badge,
    this.color,
    this.diameter = 96,
    super.key,
  });

  /// The circle's tint. Defaults to the theme's primary.
  ///
  /// A person's portrait takes the same colour as their glyph elsewhere, so a
  /// row and a profile do not describe the same person two ways.
  final Color? color;

  /// One or two letters. Empty falls back to a person glyph.
  final String initials;
  final String? title;
  final String? subtitle;

  /// A small pill inside the circle, under the letters — how many people the
  /// family holds. Lighter than the circle so it reads as sitting on it.
  final Widget? badge;

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: <Widget>[
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[tint.withValues(alpha: 0.75), tint],
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (initials.isEmpty)
                  Icon(Icons.person, size: diameter * 0.5, color: Colors.white)
                else
                  // Shrunk to fit rather than clipped, so a word can stand in
                  // for a picture until there is one.
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: diameter * 0.18,
                    ),
                    child: FittedBox(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: diameter * 0.34,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (badge case final pill?) ...<Widget>[
                  const SizedBox(height: 4),
                  pill,
                ],
              ],
            ),
          ),
          if (title case final name?) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (subtitle case final note?) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              note,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: GroupedColors.secondaryLabel(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A glyph, optionally with a count, on a tinted pill inside an
/// [AvatarHeader].
class CountBadge extends StatelessWidget {
  const CountBadge({required this.icon, this.label, super.key});

  final IconData icon;

  /// Omitted when the glyph says everything — a sex, say, which is one of
  /// three things rather than a quantity.
  final String? label;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: label == null ? 5 : 9, vertical: 3),
    decoration: BoxDecoration(
      // Lifted off the circle behind it rather than given its own colour, so
      // it stays part of the avatar instead of becoming a second object.
      color: Colors.white.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: Colors.white),
        if (label case final count?) ...<Widget>[
          const SizedBox(width: 3),
          Text(
            count,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ],
    ),
  );
}

/// The search field from the phone: a translucent pill with a magnifier, and a
/// way to empty it again.
///
/// Floats over the list rather than sitting beside it, and blurs what passes
/// underneath — so the reader can see there is more list down there without
/// the names competing with the field.
class SearchPill extends StatelessWidget {
  const SearchPill({
    required this.controller,
    required this.hint,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = GroupedColors.secondaryLabel(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: GroupedColors.card(context).withValues(alpha: 0.82),
              hintText: hint,
              hintStyle: TextStyle(color: muted),
              prefixIcon: Icon(Icons.search, size: 20, color: muted),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.cancel, size: 18, color: muted),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              // A hairline, because the fill is translucent: over a pale card
              // the field would otherwise have no edge at all and read as
              // part of the list behind it.
              enabledBorder: _pillBorder(GroupedColors.separator(context)),
              focusedBorder: _pillBorder(Theme.of(context).colorScheme.primary),
              border: _pillBorder(GroupedColors.separator(context)),
            ),
          ),
        ),
      ),
    );
  }
}

OutlineInputBorder _pillBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(99),
  borderSide: BorderSide(color: color),
);

/// The back arrow, in a circle, the way the phone draws it.
///
/// Returns null where there is nothing to go back to, so an [AppBar] falls
/// through to no leading widget at all rather than showing a dead control.
Widget? circleBackButton(BuildContext context) {
  if (!Navigator.of(context).canPop()) return null;

  // Same metrics as the action button opposite it, so the two corners match.
  return Padding(
    padding: const EdgeInsets.only(left: 8),
    child: IconButton.filledTonal(
      icon: const Icon(Icons.chevron_left),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
}

/// The one letter shown for a family with no picture.
///
/// *Họ Nguyễn* is N, not H: the leading word says "the family of" and carries
/// no identity. Dropping it is a display choice, not a rule about names — the
/// stored name is untouched.
String familyInitial(String name) {
  // Folded forms: the comparison below folds too, so an entry carrying its
  // tone marks would never match anything.
  const generic = <String>{
    'ho',
    'gia',
    'dinh',
    'chi',
    'nhanh',
    'family',
    'the',
    'clan',
  };

  final words = name.trim().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return '';

  final named = words.firstWhere(
    (w) => !generic.contains(foldForSearch(w)),
    orElse: () => words.first,
  );
  return named.characters.first.toUpperCase();
}

/// The one or two letters shown when there is no picture.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return '';
  if (words.length == 1) return words.first.characters.first.toUpperCase();
  return (words.first.characters.first + words.last.characters.first)
      .toUpperCase();
}
