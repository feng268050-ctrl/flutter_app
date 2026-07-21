import 'package:flutter/foundation.dart';

/// Refcount-safe host session for CyberIME overlay + dialog lift.
///
/// Exposes [keyboardHeight] (panel height only). Dialog hosts MUST compute
/// card translation from remaining viewport geometry (see
/// `CyberKeyboardAvoidingLift`) — do not translate by the full panel height.
class CyberImeSession extends ChangeNotifier {
  CyberImeSession({this.margin = defaultMargin});

  /// Shared App-wide session (Settings / dialogs).
  static final CyberImeSession shared = CyberImeSession();

  static const double defaultMargin = 24;
  static const double defaultPanelHeight = 280;

  /// Preferred gap between card and keyboard when space is tight.
  final double margin;

  int _attachCount = 0;
  double _panelHeight = 0;
  VoidCallback? onKeyboardShown;
  VoidCallback? onKeyboardHidden;
  VoidCallback? onLiftApplied;
  VoidCallback? onBackdropRefresh;

  int get attachCount => _attachCount;

  bool get isVisible => _attachCount > 0 && _panelHeight > 0;

  /// Keyboard panel height while visible; zero when hidden.
  double get keyboardHeight => isVisible ? _panelHeight : 0;

  double get panelHeight => keyboardHeight;

  /// ValueListenable of [keyboardHeight] for [CyberKeyboardAvoidingLift].
  late final ValueNotifier<double> keyboardHeightListenable =
      _KeyboardHeightNotifier(this);

  /// Attach a keyboard session. Returns a detach token.
  VoidCallback attach({
    double panelHeight = defaultPanelHeight,
  }) {
    _attachCount++;
    _panelHeight = panelHeight;
    final first = _attachCount == 1;
    notifyListeners();
    keyboardHeightListenable.value = keyboardHeight;
    if (first) {
      onKeyboardShown?.call();
      onLiftApplied?.call();
      onBackdropRefresh?.call();
    }
    var detached = false;
    return () {
      if (detached) return;
      detached = true;
      detach();
    };
  }

  void updatePanelHeight(double height) {
    if (_panelHeight == height) return;
    _panelHeight = height;
    notifyListeners();
    keyboardHeightListenable.value = keyboardHeight;
    if (isVisible) {
      onLiftApplied?.call();
      onBackdropRefresh?.call();
    }
  }

  void detach() {
    if (_attachCount <= 0) return;
    _attachCount--;
    if (_attachCount == 0) {
      _panelHeight = 0;
      onKeyboardHidden?.call();
      onLiftApplied?.call();
      onBackdropRefresh?.call();
    }
    notifyListeners();
    keyboardHeightListenable.value = keyboardHeight;
  }

  @visibleForTesting
  void reset() {
    _attachCount = 0;
    _panelHeight = 0;
    notifyListeners();
    keyboardHeightListenable.value = 0;
  }
}

class _KeyboardHeightNotifier extends ValueNotifier<double> {
  _KeyboardHeightNotifier(this._session) : super(_session.keyboardHeight);

  final CyberImeSession _session;

  @override
  double get value => _session.keyboardHeight;
}
