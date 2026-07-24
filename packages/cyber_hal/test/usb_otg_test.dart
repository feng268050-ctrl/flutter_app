import 'dart:io';

import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/usb_otg/linux_usb_otg.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_hal/usb_otg/usb_otg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UsbOtgMode.tryParse accepts aliases', () {
    expect(UsbOtgMode.tryParse('debug'), UsbOtgMode.debug);
    expect(UsbOtgMode.tryParse('usb-debug'), UsbOtgMode.debug);
    expect(UsbOtgMode.tryParse('MTP'), UsbOtgMode.mtp);
    expect(UsbOtgMode.tryParse('host'), UsbOtgMode.host);
    expect(UsbOtgMode.tryParse('nope'), isNull);
  });

  test('UsbOtgSupport.fromIniMap parses bools', () {
    expect(
      UsbOtgSupport.fromIniMap({
        'debug_only': 'true',
        'auto_host_support': 'false',
      }).debugOnly,
      isTrue,
    );
    expect(
      UsbOtgSupport.fromIniMap({
        'debug_only': '0',
        'auto_host_support': '1',
      }).autoHostSupport,
      isTrue,
    );
  });

  test('StubUsbOtg defaults and pickerModes', () async {
    final otg = StubUsbOtg();
    expect(await otg.getMode(), UsbOtgMode.debug);
    expect(await otg.pickerModes(), [
      UsbOtgMode.debug,
      UsbOtgMode.mtp,
      UsbOtgMode.host,
    ]);
    otg.support = const UsbOtgSupport(autoHostSupport: true);
    expect(await otg.pickerModes(), [UsbOtgMode.debug, UsbOtgMode.mtp]);
    otg.support = const UsbOtgSupport(debugOnly: true);
    expect(await otg.pickerModes(), [UsbOtgMode.debug]);
  });

  test('StubUsbOtg setMode notifies updates', () async {
    final otg = StubUsbOtg();
    var pulses = 0;
    otg.updates.listen((_) => pulses++);
    await otg.setMode(UsbOtgMode.mtp);
    await Future<void>.delayed(Duration.zero);
    expect(await otg.getMode(), UsbOtgMode.mtp);
    expect(pulses, 1);
  });

  test('LinuxUsbOtg getMode reads conf default debug', () async {
    final dir = await Directory.systemTemp.createTemp('usb-otg-');
    final conf = '${dir.path}/usb-otg.conf';
    final otg = LinuxUsbOtg(helper: const [], confPath: conf);
    expect(await otg.getMode(), UsbOtgMode.debug);

    await upsertKeyValueConfFile(conf, {'mode': 'mtp'});
    expect(await otg.getMode(), UsbOtgMode.mtp);
    await dir.delete(recursive: true);
  });

  test('LinuxUsbOtg getSupport reads ini', () async {
    final dir = await Directory.systemTemp.createTemp('usb-otg-ini-');
    final path = '${dir.path}/usb-otg.ini';
    final otg = LinuxUsbOtg(helper: const [], iniPath: path);
    expect((await otg.getSupport()).debugOnly, isFalse);

    await File(path).writeAsString(
      'debug_only=true\nauto_host_support=false\n',
    );
    final s = await otg.getSupport();
    expect(s.debugOnly, isTrue);
    expect(await otg.pickerModes(), [UsbOtgMode.debug]);
    await dir.delete(recursive: true);
  });
}
