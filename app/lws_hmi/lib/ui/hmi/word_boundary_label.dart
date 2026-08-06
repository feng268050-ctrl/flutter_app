import 'package:flutter/material.dart';

/// Label that wraps only between whitespace-separated tokens (never mid-word).
class WordBoundaryLabel extends StatelessWidget {
  const WordBoundaryLabel({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines = 2,
    this.spacing,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int maxLines;

  /// Gap between word chips. Defaults to the painted width of `' '`.
  final double? spacing;

  /// Painted width of a single space under [style] (LTR).
  static double spaceWidth(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  WrapAlignment get _wrapAlignment => switch (textAlign) {
        TextAlign.center => WrapAlignment.center,
        TextAlign.right || TextAlign.end => WrapAlignment.end,
        _ => WrapAlignment.start,
      };

  @override
  Widget build(BuildContext context) {
    final words =
        text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return const SizedBox.shrink();
    // Single line, or a single token (CJK): ordinary Text is fine.
    if (maxLines <= 1 || words.length == 1) {
      return Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines < 1 ? 1 : maxLines,
        softWrap: maxLines > 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Wrap(
      alignment: _wrapAlignment,
      spacing: spacing ?? spaceWidth(style),
      runSpacing: 0,
      children: [
        for (final word in words)
          Text(
            word,
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: style,
          ),
      ],
    );
  }
}

/// Multi-paragraph body that wraps only between whitespace-separated tokens.
///
/// Blank lines (`\n\n`) become [sectionGap]; single `\n` becomes [lineGap].
/// CJK / single-token runs fall back to ordinary soft-wrapping [Text].
class WordBoundaryBody extends StatelessWidget {
  const WordBoundaryBody({
    super.key,
    required this.text,
    required this.style,
    this.sectionGap = 20,
    this.lineGap,
  });

  final String text;
  final TextStyle style;

  /// Gap between `\n\n`-separated blocks (numbered sections).
  final double sectionGap;

  /// Gap between hard `\n` lines inside a block. Defaults to ~0.2× font size.
  final double? lineGap;

  @override
  Widget build(BuildContext context) {
    final sections = text
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList(growable: false);
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }
    final hardLineGap = lineGap ?? (style.fontSize ?? 14) * 0.2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) SizedBox(height: sectionGap),
          _section(sections[i], hardLineGap),
        ],
      ],
    );
  }

  Widget _section(String section, double hardLineGap) {
    final lines = section
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
    if (lines.length <= 1) {
      return _WordBoundaryLine(text: lines.isEmpty ? section : lines.first, style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) SizedBox(height: hardLineGap),
          _WordBoundaryLine(text: lines[i], style: style),
        ],
      ],
    );
  }
}

final class _WordBoundaryLine extends StatelessWidget {
  const _WordBoundaryLine({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return const SizedBox.shrink();
    }
    // No spaces (CJK): let the engine wrap normally.
    if (words.length == 1) {
      return Text(text, style: style);
    }
    return Wrap(
      spacing: WordBoundaryLabel.spaceWidth(style),
      runSpacing: 0,
      children: [
        for (final word in words)
          Text(
            word,
            softWrap: false,
            maxLines: 1,
            style: style,
          ),
      ],
    );
  }
}
