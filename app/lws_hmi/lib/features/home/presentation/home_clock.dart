import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:lws_hmi/app/theme/hmi_display_typography.dart';

/// Design tokens from lws-ui `FrostClockAppearance` / `frostui_clock_colors.xml`.
///
/// Aliases [CyberClockAppearance] for stable HomeClock call sites.
abstract final class HomeClockTokens {
  static const verticalScale = CyberClockAppearance.verticalScale;
  static const captureScaleDivisor = CyberClockAppearance.captureScaleDivisor;
  static const fillTop = CyberClockAppearance.fillTop;
  static const fillMid = CyberClockAppearance.fillMid;
  static const fillBottom = CyberClockAppearance.fillBottom;
  static const milkOverlay = CyberClockAppearance.milkOverlay;
  static const borderShadow = CyberClockAppearance.borderShadow;

  /// Date/weekday line relative to [HomeClock.fontSize].
  static const dateFontScale = 0.30;

  /// Gap between date and time lines (× time fontSize).
  /// Date stays at the top of the column; larger gap only moves time down.
  static const dateGapScale = 0.18;
}

/// Home hero clock — stand-in for lws-ui `FrostHomeClockView`.
///
/// Sampling uses the shared [CyberBlurSampleMode] API. Realtime mode paints
/// glyph fill only (no rectangular [CyberBackdropBlur] plate). Frozen modes
/// capture from [CyberBlurBackdropScope] and clip frost to glyphs via dstIn.
///
/// Appearance tokens come from [CyberClockAppearance] (via [HomeClockTokens]).
/// See [CyberClockNotes] for glyph-clip live-blur limits on RK3566.
/// Glyph chrome (vertical scale, milk overlay, edge stroke) follows lws-ui;
/// font is system bold (not Roboto Bold).
class HomeClock extends StatefulWidget {
  const HomeClock({
    super.key,
    this.fontSize = HmiDisplayTypography.clockSize,
    this.sampleMode = CyberBlurSampleMode.realtime,
    this.blurIntensity = CyberBlurIntensity.extreme,
    this.blurTint = CyberBlurTint.warm,
    this.now,
    this.listenable,
    this.use24HourFormat = true,
    this.showDateLine = true,
  });

  /// Design text size (product Home: 120; lws-ui XML: 150sp).
  final double fontSize;

  /// Same sampling API as [CyberBackdropBlur] / home quick actions.
  final CyberBlurSampleMode sampleMode;

  final CyberBlurIntensity blurIntensity;
  final CyberBlurTint blurTint;

  /// Optional OS wall clock; defaults to [DateTime.now].
  final DateTime Function()? now;

  /// When set, rebuilds clock text when the listenable notifies.
  final Listenable? listenable;

  /// When false, shows 12-hour time (localized meridiem when context allows).
  final bool use24HourFormat;

  /// System date + weekday under the time (same frost glyph chrome).
  final bool showDateLine;

  @override
  State<HomeClock> createState() => _HomeClockState();
}

class _HomeClockState extends State<HomeClock> {
  Timer? _secondTimer;
  late String _text;
  late String _dateText;
  ui.Image? _frozen;
  bool _capturePending = false;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  double get _dateFontSize =>
      widget.fontSize * HomeClockTokens.dateFontScale;

  @override
  void initState() {
    super.initState();
    _text = _formatFallback(_now);
    _dateText = _formatDateFallback(_now);
    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    widget.listenable?.addListener(_onExternalTick);
    if (widget.sampleMode != CyberBlurSampleMode.realtime) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestFrozenSample());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onTick();
  }

  @override
  void didUpdateWidget(HomeClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable?.removeListener(_onExternalTick);
      widget.listenable?.addListener(_onExternalTick);
    }
    if (oldWidget.use24HourFormat != widget.use24HourFormat ||
        oldWidget.now != widget.now ||
        oldWidget.showDateLine != widget.showDateLine) {
      _onTick();
    }
    if (oldWidget.sampleMode != widget.sampleMode) {
      if (widget.sampleMode == CyberBlurSampleMode.realtime) {
        _frozen?.dispose();
        _frozen = null;
      } else {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _requestFrozenSample());
      }
    }
  }

  static String _formatFallback(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _formatDateFallback(DateTime t) {
    return formatProductDateWeekday(t, const Locale('en'));
  }

  String _format(DateTime t) {
    if (!mounted) {
      return _formatFallback(t);
    }
    try {
      return MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(t),
        alwaysUse24HourFormat: widget.use24HourFormat,
      );
    } catch (_) {
      return _formatFallback(t);
    }
  }

  String _formatDate(DateTime t) {
    if (!mounted) {
      return _formatDateFallback(t);
    }
    try {
      return formatProductDateWeekday(t, Localizations.localeOf(context));
    } catch (_) {
      return _formatDateFallback(t);
    }
  }

  @override
  void dispose() {
    widget.listenable?.removeListener(_onExternalTick);
    _secondTimer?.cancel();
    _frozen?.dispose();
    super.dispose();
  }

  void _onExternalTick() => _onTick();

  void _onTick() {
    if (!mounted) {
      return;
    }
    final now = _now;
    final next = _format(now);
    final nextDate =
        widget.showDateLine ? _formatDate(now) : '';
    if (next == _text && nextDate == _dateText) {
      return;
    }
    setState(() {
      _text = next;
      _dateText = nextDate;
    });
    if (widget.sampleMode == CyberBlurSampleMode.onChange) {
      _requestFrozenSample();
    }
  }

  void _requestFrozenSample() {
    if (widget.sampleMode == CyberBlurSampleMode.firstFrame &&
        _frozen != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureBackdrop());
  }

  TextPainter _measure(
    String value,
    double fontSize, {
    double letterSpacing = 0,
  }) {
    // Intentionally fixed-size display chrome; does not follow user text size.
    // Caller applies [HmiTextScale.displayTextScalerOf] into [fontSize].
    return TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: letterSpacing,
          color: Colors.white,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
    )..layout();
  }

  Widget _glyphLine({
    required String text,
    required double fontSize,
    required Color overlay,
    Key? semanticsKey,
    double letterSpacing = 0,
    double? widthOverride,
  }) {
    final measured = _measure(text, fontSize, letterSpacing: letterSpacing);
    final glyphW = widthOverride ?? measured.width;
    final glyphH = measured.height * HomeClockTokens.verticalScale;
    return SizedBox(
      width: glyphW,
      height: glyphH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(glyphW, glyphH),
            painter: _HomeClockPainter(
              text: text,
              fontSize: fontSize,
              mode: widget.sampleMode,
              frozen: _frozen,
              overlay: overlay,
              edgeStrokePx: fontSize >= widget.fontSize * 0.8 ? 1.25 : 1.0,
              letterSpacing: letterSpacing,
            ),
          ),
          Opacity(
            opacity: 0,
            child: Text(
              text,
              key: semanticsKey,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: letterSpacing,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Plain date/weekday under the frost time (no glyph blur chrome).
  Widget _dateLine() {
    return Text(
      _dateText,
      key: const ValueKey('home-clock-date'),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xCCF2F2F2),
        fontSize: _dateFontSize,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.fontSize * (10 / 150);
    final overlay = cyberBlurOverlayColor(
      intensity: widget.blurIntensity,
      tint: widget.blurTint,
    );
    final showDate = widget.showDateLine && _dateText.isNotEmpty;
    final gap = widget.fontSize * HomeClockTokens.dateGapScale;
    final timeW = _measure(_text, widget.fontSize).width;

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showDate) ...[
          _dateLine(),
          SizedBox(height: gap),
        ],
        _glyphLine(
          text: _text,
          fontSize: widget.fontSize,
          overlay: overlay,
          semanticsKey: const ValueKey('home-clock-text'),
          widthOverride: timeW,
        ),
      ],
    );

    return Semantics(
      label: 'Home clock',
      value: showDate ? '$_dateText  $_text' : _text,
      child: Padding(
        // No top pad — Home places this block at Quick/Engineer top (55).
        padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
        child: column,
      ),
    );
  }

  Future<void> _captureBackdrop() async {
    if (!mounted ||
        _capturePending ||
        widget.sampleMode == CyberBlurSampleMode.realtime) {
      return;
    }
    final self = context.findRenderObject();
    if (self is! RenderBox || !self.hasSize || self.size.isEmpty) {
      return;
    }

    final scope = CyberBlurBackdropScope.maybeOf(context);
    final boundary = scope?.renderBoundary;
    if (boundary == null || !boundary.hasSize) {
      return;
    }

    _capturePending = true;
    try {
      final scale = 1.0 / HomeClockTokens.captureScaleDivisor;
      final full = await boundary.toImage(pixelRatio: scale);
      if (!mounted) {
        full.dispose();
        return;
      }

      final selfTopLeft = self.localToGlobal(Offset.zero);
      final boundaryTopLeft = boundary.localToGlobal(Offset.zero);
      final localOrigin = selfTopLeft - boundaryTopLeft;
      final src = Rect.fromLTWH(
        localOrigin.dx * scale,
        localOrigin.dy * scale,
        self.size.width * scale,
        self.size.height * scale,
      ).intersect(
        Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()),
      );

      if (src.width < 1 || src.height < 1) {
        full.dispose();
        return;
      }

      final cropped = await _cropImage(full, src);
      full.dispose();
      final blurred = await _blurImage(cropped, widget.blurIntensity.sigma);
      cropped.dispose();
      if (!mounted) {
        blurred.dispose();
        return;
      }

      setState(() {
        _frozen?.dispose();
        _frozen = blurred;
      });
    } catch (_) {
      // Fall back to gradient glyphs.
    } finally {
      _capturePending = false;
    }
  }

  static Future<ui.Image> _cropImage(ui.Image src, Rect srcRect) async {
    final w = srcRect.width.round().clamp(1, src.width);
    final h = srcRect.height.round().clamp(1, src.height);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      src,
      srcRect,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    try {
      return picture.toImage(w, h);
    } finally {
      picture.dispose();
    }
  }

  static Future<ui.Image> _blurImage(ui.Image src, double sigma) async {
    Future<ui.Image> pass(ui.Image input) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        );
      canvas.drawImage(input, Offset.zero, paint);
      final picture = recorder.endRecording();
      try {
        return picture.toImage(input.width, input.height);
      } finally {
        picture.dispose();
      }
    }

    final first = await pass(src);
    final second = await pass(first);
    first.dispose();
    return second;
  }
}

class _HomeClockPainter extends CustomPainter {
  _HomeClockPainter({
    required this.text,
    required this.fontSize,
    required this.mode,
    required this.frozen,
    required this.overlay,
    required this.edgeStrokePx,
    this.letterSpacing = 0,
  });

  final String text;
  final double fontSize;
  final CyberBlurSampleMode mode;
  final ui.Image? frozen;
  final Color overlay;
  final double edgeStrokePx;
  final double letterSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty || size.isEmpty) {
      return;
    }

    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: letterSpacing,
      color: Colors.white,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final center = Offset(size.width / 2, size.height / 2);
    final textOffset = Offset(
      center.dx - painter.width / 2,
      center.dy - painter.height / 2,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, HomeClockTokens.verticalScale);
    canvas.translate(-center.dx, -center.dy);

    final layerBounds = Offset.zero & size;

    if (mode != CyberBlurSampleMode.realtime && frozen != null) {
      canvas.saveLayer(layerBounds, Paint());
      paintImage(
        canvas: canvas,
        rect: layerBounds,
        image: frozen!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
      );
      canvas.drawRect(layerBounds, Paint()..color = overlay);
      canvas.drawRect(
        layerBounds,
        Paint()..color = HomeClockTokens.milkOverlay,
      );
      canvas.saveLayer(layerBounds, Paint()..blendMode = BlendMode.dstIn);
      painter.paint(canvas, textOffset);
      canvas.restore();
      canvas.restore();
    } else if (mode == CyberBlurSampleMode.realtime) {
      // Live BackdropFilter under glyphs; warm mist + milk as glyph fill.
      final fillPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(color: overlay),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      fillPainter.paint(canvas, textOffset);
      final milkPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(color: HomeClockTokens.milkOverlay),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      milkPainter.paint(canvas, textOffset);
    } else {
      final shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          HomeClockTokens.fillTop,
          HomeClockTokens.fillMid,
          HomeClockTokens.fillBottom,
        ],
        stops: [0.0, 0.42, 1.0],
      ).createShader(
        Rect.fromLTWH(
          textOffset.dx,
          textOffset.dy,
          painter.width,
          painter.height,
        ),
      );
      final fillPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(
            color: null,
            foreground: Paint()..shader = shader,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      fillPainter.paint(canvas, textOffset);
    }

    canvas.restore();
    _paintEdge(canvas, painter, textOffset, center);
  }

  void _paintEdge(
    Canvas canvas,
    TextPainter layoutPainter,
    Offset textOffset,
    Offset center,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, HomeClockTokens.verticalScale);
    canvas.translate(-center.dx, -center.dy);

    // lws-ui: per-glyph edge gradient on that glyph's bounds. A single
    // diagonal across "HH:mm" leaves middle digits/colon in the dark mid-stop.
    for (var i = 0; i < text.length; i++) {
      final boxes = layoutPainter.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      if (boxes.isEmpty) {
        continue;
      }
      final box = boxes.first;
      final charBounds = Rect.fromLTRB(
        textOffset.dx + box.left,
        textOffset.dy + box.top,
        textOffset.dx + box.right,
        textOffset.dy + box.bottom,
      );
      final charOffset = Offset(charBounds.left, textOffset.dy);
      final ch = text[i];
      final edgeShader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xCCFFFFFF),
          Color(0xB0E0E0E0),
          Color(0x88000000),
          Color(0xB0E0E0E0),
          Color(0xCCFFFFFF),
        ],
        stops: [0.0, 0.22, 0.5, 0.78, 1.0],
      ).createShader(charBounds);

      TextPainter(
        text: TextSpan(
          text: ch,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.0,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = edgeStrokePx * 0.72
              ..strokeJoin = StrokeJoin.round
              ..color = HomeClockTokens.borderShadow,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, charOffset);

      TextPainter(
        text: TextSpan(
          text: ch,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.0,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = edgeStrokePx
              ..strokeJoin = StrokeJoin.round
              ..shader = edgeShader,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, charOffset);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HomeClockPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.mode != mode ||
        oldDelegate.frozen != frozen ||
        oldDelegate.overlay != overlay ||
        oldDelegate.edgeStrokePx != edgeStrokePx ||
        oldDelegate.letterSpacing != letterSpacing;
  }
}
