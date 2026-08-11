import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/bluetooth/bluetoothctl_parse.dart';
import 'package:lws_hmi/platform/ethernet/ethernet_models.dart';
import 'package:lws_hmi/platform/http/http_proxy_config.dart';
import 'package:lws_hmi/platform/wifi/wifi_ap_list.dart';
import 'package:lws_hmi/platform/wifi/wifi_link_parse.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';
import 'package:lws_hmi/platform/wifi/wpa_cli_parse.dart';

void main() {
  group('WpaCliParse', () {
    test('needsScanSsid only when hidden', () {
      expect(WpaCliParse.needsScanSsid(hidden: true), isTrue);
      expect(WpaCliParse.needsScanSsid(hidden: false), isFalse);
    });

    test('parses status map and phase', () {
      const raw = '''
bssid=aa:bb:cc:dd:ee:ff
ssid=CafeWiFi
wpa_state=COMPLETED
ip_address=192.168.1.20
''';
      final st = WpaCliParse.status(raw);
      expect(st['ssid'], 'CafeWiFi');
      expect(
        WpaCliParse.phaseFromStatus(st),
        WifiConnectionPhase.connected,
      );
      expect(
        WpaCliParse.phaseFromStatus({'wpa_state': 'ASSOCIATING'}),
        WifiConnectionPhase.associating,
      );
    });

    test('parses scan_results keeping strongest SSID', () {
      const raw = '''
bssid / frequency / signal level / flags / ssid
aa:bb:cc:dd:ee:01	2412	-70	[WPA2-PSK-CCMP][ESS]	HomeNet
aa:bb:cc:dd:ee:02	2437	-70	[ESS]	OpenNet
aa:bb:cc:dd:ee:03	2412	-40	[WPA2-PSK-CCMP][ESS]	HomeNet
''';
      final aps = WpaCliParse.scanResults(raw);
      expect(aps.length, 2);
      expect(aps.first.ssid, 'HomeNet');
      expect(aps.first.signalDbm, -40);
      expect(aps.map((a) => a.ssid), containsAll(['HomeNet', 'OpenNet']));
    });

    test('parses list_networks', () {
      const raw = '''
network id / ssid / bssid / flags
0	HomeNet	any	[CURRENT]
1	"HiddenSSID"	any	
''';
      final nets = WpaCliParse.listNetworks(raw);
      expect(nets.map((n) => n.ssid), ['HomeNet', 'HiddenSSID']);
    });

    test('quoteWpaString escapes', () {
      expect(WpaCliParse.quoteWpaString(r'a"b\c'), r'"a\"b\\c"');
    });
  });

  group('WlanIpv4Store', () {
    test('round-trips dhcp and static', () {
      const dhcp = WlanIpv4Config.dhcpDefault;
      expect(WlanIpv4Store.parse(WlanIpv4Store.serialize(dhcp)).mode,
          WlanIpv4Mode.dhcp);

      const staticCfg = WlanIpv4Config(
        mode: WlanIpv4Mode.staticMode,
        address: '10.0.0.8',
        prefixLength: 24,
        gateway: '10.0.0.1',
        dnsMode: WlanDnsMode.manual,
        dnsServers: ['1.1.1.1'],
      );
      final back = WlanIpv4Store.parse(WlanIpv4Store.serialize(staticCfg));
      expect(back.mode, WlanIpv4Mode.staticMode);
      expect(back.address, '10.0.0.8');
      expect(back.prefixLength, 24);
      expect(back.gateway, '10.0.0.1');
      expect(back.dnsMode, WlanDnsMode.manual);
      expect(back.dns, '1.1.1.1');
      expect(back.dnsServers, ['1.1.1.1']);
    });

    test('legacy static dns infers manual', () {
      final back = WlanIpv4Store.parse(
        'mode=static\naddress=10.0.0.8\nprefix=24\ngateway=10.0.0.1\ndns=8.8.8.8\n',
      );
      expect(back.dnsMode, WlanDnsMode.manual);
      expect(back.dnsServers, ['8.8.8.8']);
    });

    test('round-trips multi dns manual under dhcp', () {
      const cfg = WlanIpv4Config(
        mode: WlanIpv4Mode.dhcp,
        dnsMode: WlanDnsMode.manual,
        dnsServers: ['1.1.1.1', '8.8.8.8'],
      );
      final back = WlanIpv4Store.parse(WlanIpv4Store.serialize(cfg));
      expect(back.mode, WlanIpv4Mode.dhcp);
      expect(back.dnsMode, WlanDnsMode.manual);
      expect(back.dnsServers, ['1.1.1.1', '8.8.8.8']);
    });
  });

  group('EthIpv4Store', () {
    test('round-trips dhcp and static', () {
      const dhcp = EthIpv4Config.dhcpDefault;
      expect(
        EthIpv4Store.parse(EthIpv4Store.serialize(dhcp)).mode,
        EthIpv4Mode.dhcp,
      );

      const staticCfg = EthIpv4Config(
        mode: EthIpv4Mode.staticMode,
        address: '192.168.1.50',
        prefixLength: 24,
        gateway: '192.168.1.1',
        dnsMode: EthDnsMode.manual,
        dnsServers: <String>['8.8.8.8'],
      );
      final back = EthIpv4Store.parse(EthIpv4Store.serialize(staticCfg));
      expect(back.mode, EthIpv4Mode.staticMode);
      expect(back.address, '192.168.1.50');
      expect(back.prefixLength, 24);
      expect(back.gateway, '192.168.1.1');
      expect(back.dnsMode, EthDnsMode.manual);
      expect(back.dns, '8.8.8.8');
    });
  });

  group('WifiApList', () {
    test('available excludes connected and keeps strongest', () {
      const aps = [
        WifiAccessPoint(ssid: 'Cafe', signalDbm: -80, flags: '[ESS]'),
        WifiAccessPoint(ssid: 'Cafe', signalDbm: -40, flags: '[ESS]'),
        WifiAccessPoint(ssid: 'Other', signalDbm: -50, flags: '[ESS]'),
      ];
      final avail = WifiApList.available(scanned: aps, connectedSsid: 'Cafe');
      expect(avail.map((a) => a.ssid), ['Other']);
      final all = WifiApList.strongestBySsid(aps);
      expect(all.first.ssid, 'Cafe');
      expect(all.first.signalDbm, -40);
    });

    test('partitionMyAndOther separates saved and scan', () {
      const saved = [
        WifiSavedNetwork(networkId: 0, ssid: 'Home'),
      ];
      const scanned = [
        WifiAccessPoint(ssid: 'Home', signalDbm: -40),
        WifiAccessPoint(ssid: 'Cafe', signalDbm: -55),
      ];
      final parts = WifiApList.partitionMyAndOther(
        saved: saved,
        scanned: scanned,
        connectedSsid: 'Home',
      );
      expect(parts.myNetworks.map((a) => a.ssid), ['Home']);
      expect(parts.otherNetworks.map((a) => a.ssid), ['Cafe']);
    });
  });

  group('WifiLinkParse', () {
    test('parses inet/gateway/dns', () {
      expect(
        WifiLinkParse.inet4(
          '2: wlan0    inet 192.168.1.20/24 brd 192.168.1.255 scope global wlan0',
        ),
        (address: '192.168.1.20', prefix: 24),
      );
      expect(
        WifiLinkParse.defaultGateway(
          'default via 192.168.1.1 dev wlan0 proto dhcp metric 100',
        ),
        '192.168.1.1',
      );
      expect(
        WifiLinkParse.primaryDns('nameserver 1.1.1.1\nnameserver 8.8.8.8\n'),
        '1.1.1.1',
      );
    });
  });

  group('HttpProxyStore', () {
    test('round-trips and redacts password', () {
      const cfg = HttpProxyConfig(
        enabled: true,
        host: 'proxy.local',
        port: 3128,
        username: 'u',
        password: 'secret',
      );
      final text = HttpProxyStore.serialize(cfg);
      expect(text.contains('password=secret'), isTrue);
      expect(HttpProxyStore.redact(text).contains('secret'), isFalse);
      expect(HttpProxyStore.redact(text).contains('password=***'), isTrue);
      final back = HttpProxyStore.parse(text);
      expect(back.enabled, isTrue);
      expect(back.host, 'proxy.local');
      expect(back.port, 3128);
      expect(back.username, 'u');
      expect(back.password, 'secret');
      expect(cfg.toString().contains('secret'), isFalse);
    });
  });

  group('BluetoothctlParse', () {
    test('normalizes address', () {
      expect(
        BluetoothctlParse.normalizeAddress('aa-bb-cc-dd-ee-ff'),
        'AA:BB:CC:DD:EE:FF',
      );
    });

    test('parses show', () {
      const raw = '''
Controller AA:BB:CC:DD:EE:FF (public)
	Name: BlueZ 5.77
	Alias: hmi
	Powered: yes
	Discoverable: yes
	Pairable: yes
''';
      final info = BluetoothctlParse.parseShow(raw);
      expect(info.address, 'AA:BB:CC:DD:EE:FF');
      expect(info.name, 'hmi');
      expect(info.powered, isTrue);
      expect(info.discoverable, isTrue);
      expect(info.pairable, isTrue);
    });

    test('parses devices and info', () {
      const devices = '''
Device 11:22:33:44:55:66 Pixel Phone
Device AA:BB:CC:00:11:22 Laptop
''';
      final list = BluetoothctlParse.parseDevices(devices);
      expect(list.length, 2);
      expect(list.first.address, '11:22:33:44:55:66');
      const info = '''
Device 11:22:33:44:55:66 (public)
	Name: Pixel Phone
	Paired: yes
	Trusted: yes
	Connected: yes
''';
      final merged = BluetoothctlParse.mergeInfo(list.first, info);
      expect(merged.paired, isTrue);
      expect(merged.trusted, isTrue);
      expect(merged.connected, isTrue);
    });
  });

  group('inferBluetoothDeviceKind', () {
    test('keyboard from icon', () {
      expect(
        inferBluetoothDeviceKind(icon: 'input-keyboard'),
        BluetoothDeviceKind.keyboard,
      );
    });

    test('mouse from class of device peripheral', () {
      // Major 5 (peripheral); minor pointing bit 0x20 in bits 2–7.
      final cod = (5 << 8) | (0x20 << 2);
      expect(
        inferBluetoothDeviceKind(deviceClass: cod),
        BluetoothDeviceKind.mouse,
      );
    });

    test('HID UUID without CoD stays other', () {
      expect(
        inferBluetoothDeviceKind(
          uuids: const ['00001124-0000-1000-8000-00805f9b34fb'],
        ),
        BluetoothDeviceKind.other,
      );
    });
  });

  group('isBluetoothNearbyCandidate', () {
    test('hides MAC-only unnamed LE spam', () {
      expect(
        isBluetoothNearbyCandidate(
          const BluetoothRemoteDevice(
            address: 'AA:BB:CC:DD:EE:FF',
            name: 'AA-BB-CC-DD-EE-FF',
            discovered: true,
          ),
        ),
        isFalse,
      );
      expect(
        isBluetoothNearbyCandidate(
          const BluetoothRemoteDevice(
            address: 'AA:BB:CC:DD:EE:FF',
            discovered: true,
          ),
        ),
        isFalse,
      );
    });

    test('keeps HID / phone / audio kinds', () {
      expect(
        isBluetoothNearbyCandidate(
          const BluetoothRemoteDevice(
            address: '11:22:33:44:55:66',
            kind: BluetoothDeviceKind.keyboard,
          ),
        ),
        isTrue,
      );
      expect(
        isBluetoothNearbyCandidate(
          const BluetoothRemoteDevice(
            address: '11:22:33:44:55:66',
            name: 'Pixel',
            kind: BluetoothDeviceKind.phone,
          ),
        ),
        isTrue,
      );
    });

    test('hides named unknown LE without useful services', () {
      expect(
        isBluetoothNearbyCandidate(
          const BluetoothRemoteDevice(
            address: 'AC:8C:46:5D:3C:9F',
            name: 'lemish.light.wy0d02',
            discovered: true,
          ),
        ),
        isFalse,
      );
    });

    test('keeps named device with HID UUID', () {
      expect(
        isBluetoothNearbyCandidate(
          const BluetoothRemoteDevice(
            address: '11:22:33:44:55:66',
            name: 'BT Keyboard',
            uuids: ['00001124-0000-1000-8000-00805f9b34fb'],
          ),
        ),
        isTrue,
      );
    });
  });

  group('BluetoothOperationException', () {
    test('includes address when present', () {
      final e = BluetoothOperationException('fail', address: 'AA:BB:CC:DD:EE:FF');
      expect(e.toString(), contains('AA:BB:CC:DD:EE:FF'));
      expect(e.toString(), contains('fail'));
    });
  });
}
