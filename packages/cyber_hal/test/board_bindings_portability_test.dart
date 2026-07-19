import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_hal/bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boardsRoot = Directory.current.path.endsWith('cyber_hal')
      ? 'boards'
      : 'packages/cyber_hal/boards';

  /// Product HAL pack lives in the HMI app (not cyber_hal).
  final appHalRoot = Directory.current.path.endsWith('cyber_hal')
      ? '../../app/hmi/assets/hal'
      : 'app/hmi/assets/hal';

  test('portable-smoke: empty script helpers still construct HAL defaults', () {
    final json = File('$boardsRoot/portable-smoke.json').readAsStringSync();
    final profile = BoardProfile.fromJsonString(json);
    expect(profile.info.boardId, 'portable-smoke');
    expect(profile.ifaceFor(NetRole.ethernetPrimary), 'enp1s0');
    expect(profile.ifaceFor(NetRole.wifiStation), 'wlp2s0');
    expect(profile.routeMetricFor('wlp2s0'), 50);
    // No libexec /opt/other script keys required.
    expect(profile.helper(BoardHelperKeys.wifiStackUp), isNull);
    expect(profile.helper(BoardHelperKeys.btStackUp), isNull);
    expect(profile.helper(BoardHelperKeys.syncTime), isNull);

    final b = BoardBindings(profile);
    expect(b.ethernetIface(), 'enp1s0');
    expect(b.wifiIface(), 'wlp2s0');
    expect(b.ethernetSession().iface, 'enp1s0');
    expect(b.wifiSession().iface, 'wlp2s0');
    expect(b.dateTime().helperPath, '');
    expect(b.sshDebug().enableHelper, isEmpty);
    expect(b.usbDebug().helper, isEmpty);
    expect(b.usbDebug().otgModePath, '');
    expect(b.mediaAudio().changeVolumeCommand, isEmpty);
    expect(b.mediaAudio().a2dpVolumeCommand, isEmpty);
    expect(b.mediaAudio().playbackPathControl, '');
    expect(b.mediaAudio().playbackPathValue, '');
    expect(b.backlight().changeBacklightCommand, isEmpty);
    expect(b.mouse().applyMouseSettingsCommand, isEmpty);

    final radio = b.wifiRadio();
    expect(radio, isA<SystemdWifiRadio>());
    expect((radio as SystemdWifiRadio).wlanUnit, 'wlan-wpa.service');
    expect(radio.modem, isA<NoopWifiModemPort>());

    final stack = b.btStack();
    expect(stack, isA<SystemdBluezStack>());
    expect((stack as SystemdBluezStack).bluetoothUnit, 'bluetooth.service');
    expect(stack.modem, isA<NoopBtModemPort>());

    // Constructors must not throw "missing script".
    expect(() => b.wifiSession(), returnsNormally);
    expect(() => b.bluetooth(), returnsNormally);
    expect(() => b.proxy(), returnsNormally);
    expect(() => b.dateTime(), returnsNormally);
    expect(b.sysInfo().mountPoints, ['/']);
  });

  test('app board_profile injects modem + debug helpers only', () {
    final json = File('$appHalRoot/board_profile.json').readAsStringSync();
    final profile = BoardProfile.fromJsonString(json);
    expect(profile.helper(BoardHelperKeys.wifiModem),
        '/usr/libexec/bluetooth/wifibt-bringup.sh');
    expect(profile.helper(BoardHelperKeys.btModem),
        '/usr/libexec/bluetooth/wifibt-bringup.sh');
    expect(profile.helper(BoardHelperKeys.wifiStackUp), isNull);
    expect(profile.resolvedGpioAsset, 'assets/hal/gpio.json');
    expect(profile.resolvedModbusAsset, 'assets/hal/modbus.json');

    final b = BoardBindings(profile);
    expect(b.dateTime().helperPath, '');
    expect(b.ethernetIface(), 'eth0');
    expect(b.wifiIface(), 'wlan0');
    expect(b.sshDebug().enableHelper, ['/usr/libexec/hmi/enable-ssh-debug.sh']);
    expect(b.usbDebug().otgModePath,
        '/sys/devices/platform/fe8a0000.usb2-phy/otg_mode');
    expect(b.mediaAudio().playbackPathControl, 'Playback Path');
    expect(b.mediaAudio().playbackPathValue, 'RING_SPK_HP');

    final radio = b.wifiRadio();
    expect(radio, isA<SystemdWifiRadio>());
    expect((radio as SystemdWifiRadio).modem, isA<ProcessWifiModemPort>());

    final stack = b.btStack();
    expect(stack, isA<SystemdBluezStack>());
    expect((stack as SystemdBluezStack).modem, isA<ProcessBtModemPort>());
  });
}
