import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/ip_camera/presentation/ip_camera_preview.dart';
import 'package:lws_hmi/features/process_mode/presentation/live_machine_status_dialog.dart';

/// Gun-managed Live Monitor host (lws-ui `WorkStatusDialogBuilder`).
///
/// Manual “More Status” uses [showLiveMachineStatusDialog] directly and is
/// never closed by these APIs.
abstract final class WorkStatusDialogHost {
  static const gunOffDebounce = Duration(milliseconds: 500);
  static const closeDelay = Duration(milliseconds: 500);

  static const routeName = 'gun-managed-live-machine-status';

  static bool _isOpen = false;
  static BuildContext? _dialogContext;
  static Timer? _gunOffDebounceTimer;
  static Timer? _closeTimer;

  static bool get isGunManagedShowing => _isOpen;

  @visibleForTesting
  static bool get hasPendingClose =>
      _gunOffDebounceTimer != null || _closeTimer != null;

  /// Open Live Monitor without a confirm bar (gun rising edge).
  static Future<void> showNoConfirmDialog(
    BuildContext context, {
    IpCameraPreviewPlayerFactory? playerFactory,
  }) {
    cancelPendingClose();
    if (_isOpen) {
      return Future<void>.value();
    }
    _isOpen = true;
    return showLiveMachineStatusDialog(
      context,
      playerFactory: playerFactory,
      showConfirmButton: false,
      routeName: routeName,
      onDialogContext: (dialogContext) {
        _dialogContext = dialogContext;
      },
    ).whenComplete(() {
      _isOpen = false;
      _dialogContext = null;
      cancelPendingClose();
    });
  }

  /// Gun switch turned off; debounce before the delayed auto-close starts.
  static void scheduleCloseOnGunOff() {
    cancelPendingClose();
    _gunOffDebounceTimer = Timer(gunOffDebounce, () {
      _gunOffDebounceTimer = null;
      closeDialogDelayMillis();
    });
  }

  /// Cancel debounce / delayed close without dismissing.
  static void cancelPendingClose() {
    _gunOffDebounceTimer?.cancel();
    _gunOffDebounceTimer = null;
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  /// Schedule close after [closeDelay] (Enable OFF / post-debounce gun off).
  static void closeDialogDelayMillis() {
    cancelPendingClose();
    _closeTimer = Timer(closeDelay, () {
      _closeTimer = null;
      closeDialog();
    });
  }

  /// Dismiss only the gun-managed Live Monitor instance.
  static void closeDialog() {
    cancelPendingClose();
    final dialogContext = _dialogContext;
    _dialogContext = null;
    _isOpen = false;
    if (dialogContext != null && dialogContext.mounted) {
      final nav = Navigator.of(dialogContext);
      if (nav.canPop()) {
        nav.pop();
      }
    }
  }

  /// Clear host state (page dispose). Does not pop routes if already gone.
  static void clearInstance() {
    cancelPendingClose();
    _dialogContext = null;
    _isOpen = false;
  }

  @visibleForTesting
  static void debugReset() {
    cancelPendingClose();
    _dialogContext = null;
    _isOpen = false;
  }
}
