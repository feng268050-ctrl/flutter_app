import 'package:flutter/material.dart';

/// Label that wraps only between whitespace-separated tokens (never mid-word).
class WordBoundaryLabel extends StatelessWidget {
  const WordBoundaryLabel({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines = 2,
    this.spacing = 6,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int maxLines;
  final double spacing;

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
      spacing: spacing,
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
