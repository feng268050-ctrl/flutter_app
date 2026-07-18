/// LAN/WLAN on-demand SSH debug (enable-ssh-debug.sh).
abstract class SshDebugController {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}
