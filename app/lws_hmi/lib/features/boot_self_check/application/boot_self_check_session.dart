import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/boot_self_check/domain/boot_self_check_item.dart';

/// Mutable UI state for the boot self-check dialog.
final class BootSelfCheckSession extends ChangeNotifier {
  final List<_Row> _rows = <_Row>[];
  bool showFooter = false;
  bool dontShowAgain = false;
  bool dismissed = false;

  List<BootSelfCheckRowView> get rows =>
      List<BootSelfCheckRowView>.unmodifiable(_rows);

  void appendChecking(BootSelfCheckItem item) {
    _rows.add(_Row(item: item, status: BootSelfCheckStatus.checking));
    notifyListeners();
  }

  void updateStatus(BootSelfCheckItem item, BootSelfCheckStatus status) {
    final i = _rows.indexWhere((r) => r.item == item);
    if (i < 0) {
      _rows.add(_Row(item: item, status: status));
    } else {
      _rows[i] = _Row(item: item, status: status);
    }
    notifyListeners();
  }

  void revealFooter() {
    showFooter = true;
    notifyListeners();
  }

  void setDontShowAgain(bool value) {
    dontShowAgain = value;
    notifyListeners();
  }

  void markDismissed() {
    dismissed = true;
  }
}

final class BootSelfCheckRowView {
  const BootSelfCheckRowView({required this.item, required this.status});

  final BootSelfCheckItem item;
  final BootSelfCheckStatus status;
}

final class _Row implements BootSelfCheckRowView {
  const _Row({required this.item, required this.status});

  @override
  final BootSelfCheckItem item;
  @override
  final BootSelfCheckStatus status;
}
