import 'package:cyber_hal/bluetooth.dart';
import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:cyber_hal/gpio.dart';
import 'package:cyber_hal/input.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/secrets.dart';
import 'package:cyber_hal/usb_otg.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:cyber_hal/src/linux/board_helper.dart';
import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';


/// Constructs Linux HAL backends from a loaded [BoardProfile] (D22 live wiring).
///
/// Missing helper keys use **in-HAL portable defaults** (systemd / D-Bus / sysfs /
/// amixer) — never hard-coded `/usr/libexec/...` paths. Board-only quirks
/// (modem bring-up, OTG PHY, SSH debug) must be injected explicitly.
///
/// New-product contract (all modules): `docs/hal-portability.md`.
final class BoardBindings {
  const BoardBindings(this.profile);

  final BoardProfile profile;

  /// Board ids that default to software KEK when `secrets_backend` is omitted.
  static const _softwareSecretsBoardIds = <String>{
    'sim',
    'portable-smoke',
  };

  /// True when [boardId] is emulator/sim (or host smoke) — software Secrets OK
  /// as the unset-profile default.
  static bool allowsSoftwareSecretsFallback(String boardId) {
    final id = boardId.trim().toLowerCase();
    if (_softwareSecretsBoardIds.contains(id)) {
      return true;
    }
    return id.startsWith('sim_') || id.contains('virt') || id.contains('emu');
  }

  /// Resolve profile `secrets_backend` (or board-id heuristic when unset).
  ///
  /// Returns [SecretsBackendPreference.software] or
  /// [SecretsBackendPreference.optee].
  static String resolveSecretsBackend(BoardProfile profile) {
    final parsed = SecretsBackendPreference.tryParse(profile.secretsBackend);
    if (parsed != null) {
      return parsed;
    }
    if (allowsSoftwareSecretsFallback(profile.info.boardId)) {
      return SecretsBackendPreference.software;
    }
    return SecretsBackendPreference.optee;
  }

  LinuxSysInfo sysInfo({
    DeviceSnReader deviceSnReader = const DeviceSnReader(),
    String? appVersion,
    FrameTimingSampler? frameTimingSampler,
    String productIniPath = kPropertiesIniPath,
    ProductInfo? productInfo,
  }) {
    return LinuxSysInfo(
      deviceSnReader: deviceSnReader,
      appVersion: appVersion,
      mountPoints: profile.storageMounts,
      systemPartLabels: profile.systemStoragePartLabels,
      frameTimingSampler: frameTimingSampler,
      productIniPath: productIniPath,
      productInfo: productInfo,
    );
  }

  /// Read-only OS / stack version probes for OS Settings (soft-fail fields).
  LinuxPlatformVersions platformVersions({
    PlatformVersionsProcessRunner? runProcess,
    PlatformVersionsFileReader? readFile,
  }) {
    return LinuxPlatformVersions(
      runProcess: runProcess,
      readFile: readFile,
    );
  }

  /// Load [ProductInfo] from [productIniPath] (same SN rules as [sysInfo]).
  Future<ProductInfo> productInfo({
    DeviceSnReader deviceSnReader = const DeviceSnReader(),
    String productIniPath = kPropertiesIniPath,
  }) {
    return ProductInfo.load(
      path: productIniPath,
      deviceSnReader: deviceSnReader,
    );
  }

  LinuxDateTimeController dateTime() {
    return LinuxDateTimeController(
      helperPath: profile.helper(BoardHelperKeys.syncTime) ?? '',
    );
  }

  LinuxSshDebugController sshDebug() {
    final argv = profile.helperArgv(BoardHelperKeys.sshDebug);
    return LinuxSshDebugController(
      enableHelper: argv ?? const <String>[],
    );
  }

  LinuxUsbOtg usbOtg() {
    final helper = profile.helperArgv(BoardHelperKeys.usbOtgMode);
    return LinuxUsbOtg(
      helper: helper ?? const <String>[],
    );
  }

  LinuxMediaAudioController mediaAudio() {
    final a2dp = profile.helperArgv(BoardHelperKeys.btA2dpVolume);
    final vol = profile.helperArgv(BoardHelperKeys.changeVolume);
    final alsa = profile.helperList(BoardHelperKeys.alsaVolumeControls);
    return LinuxMediaAudioController(
      a2dpVolumeCommand: a2dp ?? const <String>[],
      changeVolumeCommand: vol ?? const <String>[],
      preferredVolumeControls: alsa,
      playbackPathControl:
          profile.helper(BoardHelperKeys.alsaPlaybackPathControl) ?? '',
      playbackPathValue:
          profile.helper(BoardHelperKeys.alsaPlaybackPathValue) ?? '',
      alsaOutputDevice:
          profile.helper(BoardHelperKeys.alsaOutputDevice) ?? '',
    );
  }

  LinuxSysfsBacklight backlight() {
    final cmd = profile.helperArgv(BoardHelperKeys.changeBacklight);
    final names = profile.helperList(BoardHelperKeys.backlightPreferredNames);
    return LinuxSysfsBacklight(
      changeBacklightCommand: cmd ?? const <String>[],
      preferredNames: names ??
          const <String>['backlight', 'backlight1', 'backlight2'],
    );
  }

  LinuxAutoSleep autoSleep({String preferencePath = OutputPrefs.displayConf}) {
    return LinuxAutoSleep(preferencePath: preferencePath);
  }

  LinuxOrientation orientation({
    String preferencePath = OutputPrefs.displayConf,
    List<String> changeOrientationCommand = const <String>['change-orientation'],
    List<String> restartCommand = kRestartFlutterSeatCommand,
  }) {
    return LinuxOrientation(
      preferencePath: preferencePath,
      changeOrientationCommand: changeOrientationCommand,
      restartCommand: restartCommand,
    );
  }

  LinuxWallpaper wallpaper({
    String preferencePath = OutputPrefs.displayConf,
    List<String> applyWallpaperCommand = const <String>['apply-wallpaper'],
    List<String> restartCommand = kRestartFlutterSeatCommand,
  }) {
    return LinuxWallpaper(
      preferencePath: preferencePath,
      applyWallpaperCommand: applyWallpaperCommand,
      restartCommand: restartCommand,
    );
  }

  LinuxUiScale uiScale({String preferencePath = OutputPrefs.displayConf}) {
    return LinuxUiScale(preferencePath: preferencePath);
  }

  LinuxButtonFeedback buttonFeedback({
    MediaAudioController? mediaAudio,
    String preferencePath = OutputPrefs.soundConf,
  }) {
    return LinuxButtonFeedback(
      mediaAudio: mediaAudio ?? this.mediaAudio(),
      preferencePath: preferencePath,
    );
  }

  LinuxLoadProfile loadProfile({
    String preferencePath = OutputPrefs.powerConf,
    List<String> setPowerModeCommand = const <String>['set-power-mode'],
  }) {
    return LinuxLoadProfile(
      preferencePath: preferencePath,
      setPowerModeCommand: setPowerModeCommand,
    );
  }

  LinuxKeyboard keyboard({PhysicalInputPolicy? inputPolicy}) {
    return LinuxKeyboard(inputPolicy: inputPolicy ?? physicalInputPolicy());
  }

  PhysicalInputPolicy physicalInputPolicy() {
    final cmd = profile.helperArgv(BoardHelperKeys.applyPhysicalInputPolicy);
    return PhysicalInputPolicy(
      applyPolicyCommand: cmd ?? const <String>[],
    );
  }

  LinuxMouseSettingsController mouse({PhysicalInputPolicy? inputPolicy}) {
    final policy = inputPolicy ?? physicalInputPolicy();
    final cmd = profile.helperArgv(BoardHelperKeys.applyMouseSettings);
    return LinuxMouseSettingsController(
      applyMouseSettingsCommand: cmd ?? const <String>[],
      inputPolicy: policy,
    );
  }

  LinuxEthernet ethernet() {
    return LinuxEthernet(
      profile: profile,
      routeMetrics: profile.routeMetrics,
    );
  }

  /// Stream Ethernet session for Demo / Settings (wanted + IPv4 prefs + metrics).
  LinuxEthernetSession ethernetSession() {
    return LinuxEthernetSession(
      profile: profile,
      routeMetrics: profile.routeMetrics,
    );
  }

  LinuxProxy proxy() {
    return LinuxProxy(
      applyPath: profile.helper(BoardHelperKeys.applyProxy),
    );
  }

  LinuxWifi wifi({
    WifiRadio? radio,
    KekProvider? secrets,
  }) {
    return LinuxWifi(
      profile: profile,
      radio: radio ?? wifiRadio(),
      routeMetrics: profile.routeMetrics,
      secrets: secrets ?? this.secrets(),
    );
  }

  /// Stream Wi‑Fi session for Demo / Settings (radio + Streams + metrics).
  ///
  /// Injects [secrets] so the Wi‑Fi credential vault seals via abstract KEK
  /// (App UI must not import `cyber_hal/secrets.dart`).
  LinuxWifiSession wifiSession({
    WifiRadio? radio,
    KekProvider? secrets,
  }) {
    return LinuxWifiSession(
      profile: profile,
      wifiRadio: radio ?? wifiRadio(),
      routeMetrics: profile.routeMetrics,
      secrets: secrets ?? this.secrets(),
    );
  }

  /// Default [SystemdWifiRadio]; optional modem from `helpers.wifi_modem`.
  ///
  /// Legacy `wifi_stack_up` / `wifi_stack_down` still yield [ScriptWifiRadio]
  /// when both are set (transition only).
  WifiRadio wifiRadio() {
    final up = profile.helperArgv(BoardHelperKeys.wifiStackUp);
    final down = profile.helperArgv(BoardHelperKeys.wifiStackDown);
    if (up != null && down != null) {
      return ScriptWifiRadio(stackUp: up, stackDown: down);
    }
    final modemCmd = profile.helperArgv(BoardHelperKeys.wifiModem);
    final unit = profile.helper(BoardHelperKeys.wifiWlanUnit);
    return SystemdWifiRadio(
      iface: wifiIface(),
      wlanUnit: unit ?? 'wlan-wpa.service',
      modem: modemCmd == null
          ? const NoopWifiModemPort()
          : ProcessWifiModemPort(command: modemCmd),
    );
  }

  String ethernetIface() =>
      profile.ifaceFor(NetRole.ethernetPrimary) ?? 'eth0';

  String wifiIface() => profile.ifaceFor(NetRole.wifiStation) ?? 'wlan0';

  /// Product primary uplink (get/set). Pass live sessions so [setPrimaryRole]
  /// can re-apply RouteMetric on Wi‑Fi / Ethernet.
  LinuxPrimaryNetworkController primaryNetwork({
    WifiController? wifi,
    EthernetController? ethernet,
  }) {
    return LinuxPrimaryNetworkController(
      profile: profile,
      wifi: wifi,
      ethernet: ethernet,
    );
  }


  /// Default [SystemdBluezStack]; optional modem from helpers.
  /// HOGP/evdev heal is in-controller (not a board script).
  BtStack btStack() {
    final up = profile.helperArgv(BoardHelperKeys.btStackUp);
    final down = profile.helperArgv(BoardHelperKeys.btStackDown);
    if (up != null && down != null) {
      return ScriptBtStack(
        stackUp: up,
        stackDown: down,
        a2dpUp: profile.helperArgv(BoardHelperKeys.btA2dpUp) ?? const [],
        a2dpDown: profile.helperArgv(BoardHelperKeys.btA2dpDown) ?? const [],
        ensureAgentCmd:
            profile.helperArgv(BoardHelperKeys.btEnsureAgent) ?? const [],
        stopAgentCmd:
            profile.helperArgv(BoardHelperKeys.btStopAgent) ?? const [],
        setAliasCmd: profile.helperArgv(BoardHelperKeys.btSetAlias) ?? const [],
      );
    }
    final modemCmd = profile.helperArgv(BoardHelperKeys.btModem);
    final unit = profile.helper(BoardHelperKeys.btBluetoothUnit);
    return SystemdBluezStack(
      bluetoothUnit: unit ?? 'bluetooth.service',
      modem: modemCmd == null
          ? const NoopBtModemPort()
          : ProcessBtModemPort(command: modemCmd),
      a2dpUp: profile.helperArgv(BoardHelperKeys.btA2dpUp) ?? const [],
      a2dpDown: profile.helperArgv(BoardHelperKeys.btA2dpDown) ?? const [],
    );
  }

  LinuxBluezBluetoothController bluetooth({BtStack? stack}) {
    return LinuxBluezBluetoothController(btStack: stack ?? btStack());
  }


  /// Boot / cold-start restore for prefs owned by HAL (replaces overlay
  /// `restore-settings.sh`). Soft-fails per domain.
  ///
  /// Call once after constructing backends (e.g. Demo first frame). Network and
  /// Bluetooth `syncFromSystem` also bring up `*-wanted` stacks.
  Future<void> restorePersistedSettings({
    LinuxSysfsBacklight? backlight,
    LinuxMediaAudioController? mediaAudio,
    LinuxMouseSettingsController? mouse,
    LinuxProxy? proxy,
    LinuxDateTimeController? dateTime,
    LinuxWifiSession? wifi,
    LinuxEthernetSession? ethernet,
    LinuxBluezBluetoothController? bluetooth,
  }) async {
    final bl = backlight ?? this.backlight();
    final audio = mediaAudio ?? this.mediaAudio();
    final px = proxy ?? this.proxy();
    final dt = dateTime ?? this.dateTime();
    final wifiS = wifi ?? wifiSession();
    final ethS = ethernet ?? ethernetSession();
    final bt = bluetooth ?? this.bluetooth();

    try {
      await bl.applyPersistedPreference();
    } catch (e) {
      debugPrint('restore: backlight: $e');
    }
    try {
      await audio.getVolumePercent(); // loads pref + applies amixer
    } catch (e) {
      debugPrint('restore: volume: $e');
    }
    // mouse.conf → weston.ini is applied in hmi-launch before Flutter starts;
    // skip apply-mouse-settings re-touch on boot (Settings UI still sets via helper).
    try {
      await px.restoreFromDisk();
    } catch (e) {
      debugPrint('restore: proxy: $e');
    }
    try {
      await dt.applyPersistedTimezone();
      await dt.applyPersistedSyncMode();
      await dt.applyPersistedNtpServer();
      await dt.ensureSaneForTls();
      if (await dt.getSyncMode() == TimeSyncMode.network) {
        await dt.syncFromNetwork(onlyIfStale: true);
      }
      if (await dt.getAutoTimezone()) {
        await dt.syncTimezoneFromNetwork();
      }
    } catch (e) {
      debugPrint('restore: datetime: $e');
    }
    try {
      await wifiS.syncFromSystem();
    } catch (e) {
      debugPrint('restore: wifi: $e');
    }
    try {
      await ethS.syncFromSystem();
    } catch (e) {
      debugPrint('restore: ethernet: $e');
    }
    try {
      await bt.syncFromSystem();
    } catch (e) {
      debugPrint('restore: bluetooth: $e');
    }
  }

  Future<GpioHal> gpio({AssetBundle? bundle}) {
    final asset = profile.resolvedGpioAsset;
    if (asset == null || asset.isEmpty) {
      throw const HalIoException(
        'board profile missing configs.gpio asset path',
      );
    }
    return GpioHal.fromAsset(asset: asset, bundle: bundle);
  }

  Future<ModbusHal> modbus({AssetBundle? bundle}) {
    return ModbusHal.fromProfile(profile, bundle: bundle);
  }

  /// Secrets / KEK seal provider.
  ///
  /// Selection is owned by OEM [BoardProfile.secretsBackend]
  /// (`software` | `optee`). When omitted, sim/emu boards → software; other
  /// board ids → OP-TEE. Pass [override] for host tests (e.g. [FakeKekProvider]).
  ///
  /// Product Wi‑Fi UI MUST NOT import `cyber_hal/secrets.dart`; Wi‑Fi HAL may
  /// consume this internally without exposing Secrets as a required App import.
  KekProvider secrets({
    KekProvider? override,
    DeviceBindingMaterialReader? materialReader,
    ChipIdReader? chipIdReader,
    DeviceSnReader? deviceSnReader,
    String? opteeHelperPath,
    OpteeSealRunner? opteeRunner,
  }) {
    if (override != null) {
      return override;
    }
    final backend = resolveSecretsBackend(profile);
    if (backend == SecretsBackendPreference.software) {
      return SoftwareFallbackKekProvider(
        materialReader: materialReader,
        chipIdReader: chipIdReader,
        deviceSnReader: deviceSnReader,
      );
    }
    return OpteeKekProvider(
      helperPath: opteeHelperPath ?? OpteeKekProvider.defaultHelperPath,
      runner: opteeRunner,
    );
  }

  /// OS Settings Operating System → Security **Secrets Seal** label (`software` | `op-tee`).
  ///
  /// Uses [secrets] selection only — no seal/unseal I/O.
  String secretsSealStatus({
    KekProvider? override,
    DeviceBindingMaterialReader? materialReader,
    ChipIdReader? chipIdReader,
    DeviceSnReader? deviceSnReader,
    String? opteeHelperPath,
    OpteeSealRunner? opteeRunner,
  }) {
    return SecretsSealStatus.fromProvider(
      secrets(
        override: override,
        materialReader: materialReader,
        chipIdReader: chipIdReader,
        deviceSnReader: deviceSnReader,
        opteeHelperPath: opteeHelperPath,
        opteeRunner: opteeRunner,
      ),
    );
  }

  /// Cloud Ed25519 identity (seal → Vendor Storage ID 22). Inject [store] in tests.
  CloudEd25519Identity cloudEd25519Identity({
    KekProvider? secrets,
    CloudEd25519SealedStore? store,
  }) {
    return CloudEd25519Identity(
      secrets: secrets ?? this.secrets(),
      store: store,
    );
  }
}
