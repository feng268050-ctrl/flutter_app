import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/datetime/date_time_controller.dart';
import 'package:lws_hmi/ui/demo/date_time_demo_section.dart';

class _FakeDateTimeController implements DateTimeController {
  TimeSyncMode mode = TimeSyncMode.network;
  String timezone = 'Asia/Shanghai';
  DateTime wall = DateTime(2026, 7, 15, 16, 30, 0);
  int syncCalls = 0;
  int setWallCalls = 0;

  @override
  Future<DateTime> now() async => wall;

  @override
  Future<String> getTimezone() async => timezone;

  @override
  Future<void> setTimezone(String id) async {
    timezone = id;
  }

  @override
  Future<TimeSyncMode> getSyncMode() async => mode;

  @override
  Future<void> setSyncMode(TimeSyncMode m) async {
    mode = m;
  }

  @override
  Future<void> setWallClock(DateTime local) async {
    setWallCalls++;
    wall = local;
    mode = TimeSyncMode.manual;
  }

  @override
  Future<TimeSyncResult> syncFromNetwork({bool onlyIfStale = false}) async {
    syncCalls++;
    wall = DateTime(2026, 7, 15, 17, 0, 0);
    return const TimeSyncResult(ok: true, message: 'fake sync');
  }

  @override
  Future<TimeSyncResult> ensureSaneForTls() async {
    return const TimeSyncResult(ok: true, message: 'ok');
  }

  @override
  List<NtpServerPreset> listNtpServerPresets() => NtpServerCatalog.presets;

  String ntpServerId = NtpServerCatalog.defaultId;

  @override
  Future<String> getNtpServerId() async => ntpServerId;

  @override
  Future<void> setNtpServerId(String id) async {
    ntpServerId = NtpServerCatalog.normalizeId(id);
  }

  bool autoTimezone = false;

  @override
  Future<bool> getAutoTimezone() async => autoTimezone;

  @override
  Future<TimeSyncResult> setAutoTimezone(bool enabled) async {
    autoTimezone = enabled;
    if (enabled) {
      return syncTimezoneFromNetwork();
    }
    return const TimeSyncResult(ok: true, message: 'off');
  }

  @override
  Future<TimeSyncResult> syncTimezoneFromNetwork() async {
    timezone = 'Asia/Shanghai';
    return const TimeSyncResult(ok: true, message: 'fake geo');
  }

  bool use24Hour = true;

  @override
  Future<bool> getUse24HourFormat() async => use24Hour;

  @override
  Future<void> setUse24HourFormat(bool enabled) async {
    use24Hour = enabled;
  }

  @override
  Future<List<TimezoneEntry>> listTimezoneEntries() async {
    return const [
      TimezoneEntry(id: 'UTC', utcOffsetLabel: 'UTC+00:00'),
      TimezoneEntry(id: 'Asia/Shanghai', utcOffsetLabel: 'UTC+08:00'),
      TimezoneEntry(id: 'America/Los_Angeles', utcOffsetLabel: 'UTC-07:00'),
    ];
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('Date & Time Apply and Sync Now call controller', (tester) async {
    final ctrl = _FakeDateTimeController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DateTimeDemoSection(controller: ctrl),
          ),
        ),
      ),
    );
    await tester.pump(); // post-frame _load
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Date & Time'), findsOneWidget);

    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.setWallCalls, 1);
    expect(ctrl.mode, TimeSyncMode.manual);

    await tester.tap(find.text('Sync Now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.syncCalls, 1);
  });

  testWidgets('Network mode segment updates controller', (tester) async {
    final ctrl = _FakeDateTimeController()..mode = TimeSyncMode.manual;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DateTimeDemoSection(controller: ctrl),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Network'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.mode, TimeSyncMode.network);
  });
}
