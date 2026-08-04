import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/stub.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/manual_wire_gesture.dart';
import 'package:lws_hmi/l10n/app_localizations_en.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  final l10n = AppLocalizationsEn();

  AppServices servicesWith(ModbusRtuClient modbus) {
    return AppServices(
      boardProfile: BoardProfile.fromJsonString('''
{
  "schema_version": 1,
  "board_id": "test",
  "display_name": "Test",
  "bindings": {"sys_info": "stub"}
}
'''),
      sysInfo: StubSysInfo(),
      modbusClient: modbus,
    );
  }

  ManualWireGesture gestureFor({
    required DeviceControlController controller,
    required bool retract,
    required void Function(String) onMessage,
    bool Function()? isActive,
    void Function()? onVisualChanged,
  }) {
    return ManualWireGesture(
      controller: controller,
      retract: retract,
      isEnabled: () => true,
      isActive: isActive ?? () => false,
      onMessage: onMessage,
      onVisualChanged: onVisualChanged ?? () {},
      l10n: () => l10n,
    );
  }

  test('short press feed toasts Feed+ started', () {
    fakeAsync((async) {
      final modbus = _RecordingModbus();
      final controller = DeviceControlController(servicesWith(modbus))
        ..keySwitchOn = true;
      final messages = <String>[];
      final gesture = gestureFor(
        controller: controller,
        retract: false,
        onMessage: messages.add,
      );

      gesture.pointerDown();
      gesture.pointerUp();
      async.flushMicrotasks();

      expect(messages, [DeviceControlFeedbackCopy.feedPulseSuccess(l10n)]);
      gesture.dispose();
    });
  });

  test('short press retract toasts Feed started', () {
    fakeAsync((async) {
      final modbus = _RecordingModbus();
      final controller = DeviceControlController(servicesWith(modbus))
        ..keySwitchOn = true;
      final messages = <String>[];
      final gesture = gestureFor(
        controller: controller,
        retract: true,
        onMessage: messages.add,
      );

      gesture.pointerDown();
      gesture.pointerUp();
      async.flushMicrotasks();

      expect(messages, [DeviceControlFeedbackCopy.retractPulseSuccess(l10n)]);
      gesture.dispose();
    });
  });

  test('feed latch toasts Feeding… then Stop Feed+ on next tap', () {
    fakeAsync((async) {
      final modbus = _RecordingModbus();
      final controller = DeviceControlController(servicesWith(modbus))
        ..keySwitchOn = true;
      final messages = <String>[];
      var visuals = 0;
      late final ManualWireGesture gesture;
      gesture = gestureFor(
        controller: controller,
        retract: false,
        isActive: () => controller.wireWork && !controller.wireRetracting,
        onMessage: messages.add,
        onVisualChanged: () => visuals++,
      );

      gesture.pointerDown();
      async.elapse(DeviceControlTiming.wireFeedLatchDelay);
      async.flushMicrotasks();
      expect(messages, [DeviceControlFeedbackCopy.feedOngoing(l10n)]);
      expect(gesture.latched, isTrue);
      expect(gesture.holdingRun, isFalse);
      expect(visuals, greaterThan(0));

      gesture.pointerUp();
      async.flushMicrotasks();
      // Latched: release does not stop — solid Continuous Feed stays on.
      expect(messages, [DeviceControlFeedbackCopy.feedOngoing(l10n)]);
      expect(gesture.latched, isTrue);
      expect(controller.wireWork, isTrue);

      gesture.pointerDown();
      gesture.pointerUp();
      async.flushMicrotasks();
      expect(
        messages,
        [
          DeviceControlFeedbackCopy.feedOngoing(l10n),
          DeviceControlFeedbackCopy.stopFeed(l10n),
        ],
      );
      expect(gesture.latched, isFalse);
      gesture.dispose();
    });
  });

  test('release after full 3s hold keeps continuous feed without timer race',
      () {
    fakeAsync((async) {
      final modbus = _RecordingModbus();
      final controller = DeviceControlController(servicesWith(modbus))
        ..keySwitchOn = true;
      final messages = <String>[];
      final gesture = gestureFor(
        controller: controller,
        retract: false,
        isActive: () => controller.wireWork && !controller.wireRetracting,
        onMessage: messages.add,
      );

      gesture.pointerDown();
      // Hold-run starts at 500ms; advance to just under latch timer fire,
      // then release with wall-clock ≥ 3s via promote path on up.
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();
      expect(controller.wireWork, isTrue);
      expect(gesture.latched, isFalse);

      async.elapse(const Duration(milliseconds: 2500));
      async.flushMicrotasks();
      // Timer fires during the 2500ms elapse (total 3000 from down).
      expect(gesture.latched, isTrue);

      gesture.pointerUp();
      async.flushMicrotasks();
      expect(gesture.latched, isTrue);
      expect(controller.wireWork, isTrue);
      expect(messages, [DeviceControlFeedbackCopy.feedOngoing(l10n)]);
      gesture.dispose();
    });
  });

  test('fill-complete promote latches while still holding', () {
    fakeAsync((async) {
      final modbus = _RecordingModbus();
      final controller = DeviceControlController(servicesWith(modbus))
        ..keySwitchOn = true;
      final gesture = gestureFor(
        controller: controller,
        retract: false,
        isActive: () => controller.wireWork && !controller.wireRetracting,
        onMessage: (_) {},
      );

      gesture.pointerDown();
      async.elapse(DeviceControlTiming.wireHoldToRun);
      async.flushMicrotasks();
      expect(gesture.latched, isFalse);

      gesture.promoteContinuousFeedIfHolding();
      expect(gesture.latched, isTrue);

      gesture.pointerUp();
      expect(gesture.latched, isTrue);
      expect(controller.wireWork, isTrue);
      gesture.dispose();
    });
  });
}

final class _RecordingModbus extends ModbusRtuClient {
  final writes = <(String, Object?)>[];

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    writes.add((id, value));
    return true;
  }

  @override
  Future<Object?> readAttribute(String id) async => null;

  @override
  Future<Map<String, Object?>> readGroup(String group) async => {};

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}
