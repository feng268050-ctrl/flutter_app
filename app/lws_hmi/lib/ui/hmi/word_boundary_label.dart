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

  /// Painted width of a single space under [style] + [textScaler] (LTR).
  static double spaceWidth(
    TextStyle style, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return _measureWidth(' ', style, textScaler);
  }

  static double _measureWidth(
    String text,
    TextStyle style,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: textScaler,
    )..layout();
    return painter.width;
  }

  CrossAxisAlignment get _crossAxis => switch (textAlign) {
        TextAlign.center => CrossAxisAlignment.center,
        TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.start,
      };

  WrapAlignment get _wrapAlignment => switch (textAlign) {
        TextAlign.center => WrapAlignment.center,
        TextAlign.right || TextAlign.end => WrapAlignment.end,
        _ => WrapAlignment.start,
      };

  /// Pack [words] into at most [maxLines] lines that fit [maxWidth].
  @visibleForTesting
  static List<String> packLines({
    required List<String> words,
    required TextStyle style,
    required double maxWidth,
    required int maxLines,
    TextScaler textScaler = TextScaler.noScaling,
    double? spacing,
  }) {
    if (words.isEmpty || maxLines < 1) {
      return const [];
    }
    final gap = spacing ?? spaceWidth(style, textScaler: textScaler);
    final lines = <List<String>>[];
    var current = <String>[];
    var currentWidth = 0.0;

    void pushCurrent() {
      if (current.isEmpty) {
        return;
      }
      lines.add(current);
      current = <String>[];
      currentWidth = 0.0;
    }

    for (final word in words) {
      final wordW = _measureWidth(word, style, textScaler);
      final addW = current.isEmpty ? wordW : gap + wordW;
      if (current.isNotEmpty && currentWidth + addW > maxWidth + 0.5) {
        pushCurrent();
        current.add(word);
        currentWidth = wordW;
      } else {
        current.add(word);
        currentWidth += addW;
      }
    }
    pushCurrent();

    if (lines.length <= maxLines) {
      return [for (final line in lines) line.join(' ')];
    }

    // Collapse overflow into the last allowed line (ellipsis via Text).
    final head = lines.sublist(0, maxLines - 1);
    final tail = lines.sublist(maxLines - 1).expand((e) => e).toList();
    return [
      for (final line in head) line.join(' '),
      tail.join(' '),
    ];
  }

  /// One English token — never soft-wrap mid-glyph; ellipsis if too wide.
  Widget _tokenText(String token, {required bool ellipsis}) {
    return Text(
      token,
      textAlign: textAlign,
      maxLines: 1,
      softWrap: false,
      overflow: ellipsis ? TextOverflow.ellipsis : TextOverflow.visible,
      style: style,
    );
  }

  /// Render [line] as separate non-wrapping word chips (never one soft-wrap Text).
  Widget _lineAsWordChips(
    String line, {
    required TextScaler textScaler,
    required bool ellipsisLast,
  }) {
    final words =
        line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return const SizedBox.shrink();
    }
    if (words.length == 1) {
      return _tokenText(words.first, ellipsis: ellipsisLast);
    }
    final gap = spacing ?? spaceWidth(style, textScaler: textScaler);
    return Wrap(
      alignment: _wrapAlignment,
      spacing: gap,
      runSpacing: 0,
      children: [
        for (var i = 0; i < words.length; i++)
          _tokenText(
            words[i],
            // Only the final token of an overflow line may ellipsis.
            ellipsis: ellipsisLast && i == words.length - 1,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final words =
        text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) {
      return const SizedBox.shrink();
    }

    final textScaler = MediaQuery.textScalerOf(context);

    // Single token (CJK / one English word): never soft-wrap mid-glyph.
    if (words.length == 1) {
      return _tokenText(words.first, ellipsis: true);
    }

    if (maxLines <= 1) {
      return _lineAsWordChips(
        words.join(' '),
        textScaler: textScaler,
        ellipsisLast: true,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          return Wrap(
            alignment: _wrapAlignment,
            spacing: spacing ?? spaceWidth(style, textScaler: textScaler),
            runSpacing: 0,
            children: [
              for (final word in words)
                _tokenText(word, ellipsis: false),
            ],
          );
        }
        final lines = packLines(
          words: words,
          style: style,
          maxWidth: maxW,
          maxLines: maxLines,
          textScaler: textScaler,
          spacing: spacing,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _crossAxis,
          children: [
            for (var i = 0; i < lines.length; i++)
              _lineAsWordChips(
                lines[i],
                textScaler: textScaler,
                ellipsisLast: i == lines.length - 1,
              ),
          ],
        );
      },
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
          _section(context, sections[i], hardLineGap),
        ],
      ],
    );
  }

  Widget _section(BuildContext context, String section, double hardLineGap) {
    final lines = section
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
    if (lines.length <= 1) {
      return _WordBoundaryLine(
        text: lines.isEmpty ? section : lines.first,
        style: style,
      );
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
    final textScaler = MediaQuery.textScalerOf(context);
    return Wrap(
      spacing: WordBoundaryLabel.spaceWidth(style, textScaler: textScaler),
      runSpacing: 0,
      children: [
        for (final word in words)
          Text(
            word,
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: style,
          ),
      ],
    );
  }
}
