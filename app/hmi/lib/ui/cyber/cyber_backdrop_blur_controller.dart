import 'package:flutter/foundation.dart';

/// Optional driver for [CyberBlurSampleMode.onChange] (and manual re-capture).
class CyberBackdropBlurController extends ChangeNotifier {
  int _generation = 0;

  /// Bumps whenever [requestSample] is called; consumers use this as a token.
  int get generation => _generation;

  /// Ask attached [CyberBackdropBlur] widgets to re-sample the backdrop.
  void requestSample() {
    _generation++;
    notifyListeners();
  }
}
