import 'package:cyber_ime/cyber_ime.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CyberImeFieldProfileRegistry', () {
    test('Number opens dedicated numeric pad only', () {
      final p = CyberImeFieldProfileRegistry.profile(CyberImeFieldType.number);
      expect(p.initialLayoutId, CyberImeLayoutId.numericDedicatedB);
      expect(p.allowedLayoutIds, {CyberImeLayoutId.numericDedicatedB});
      expect(p.initialKind, CyberImeKeyboardKind.numericDedicated);
    });

    test('WiFi and Password use Keyboard A profiles', () {
      final wifi = CyberImeFieldProfileRegistry.profile(CyberImeFieldType.wifi);
      final pass =
          CyberImeFieldProfileRegistry.profile(CyberImeFieldType.password);
      expect(wifi.initialLayoutId, CyberImeLayoutId.qwertyGlobal);
      expect(pass.initialLayoutId, CyberImeLayoutId.qwertyGlobal);
      expect(wifi.maskInput, isTrue);
      expect(pass.maskInput, isTrue);
      expect(
        wifi.allowedLayoutIds,
        CyberImeFieldProfile.symbolLayersPlusQwerty(),
      );
    });
  });

  group('CyberImeSession', () {
    test('detach resets keyboard height to zero', () {
      final session = CyberImeSession(margin: 24);
      expect(session.keyboardHeight, 0);
      final detach = session.attach(panelHeight: 280);
      expect(session.keyboardHeight, 280);
      detach();
      expect(session.keyboardHeight, 0);
      expect(session.isVisible, isFalse);
    });

    test('refcount keeps height until last detach', () {
      final session = CyberImeSession(margin: 10);
      final a = session.attach(panelHeight: 100);
      final b = session.attach(panelHeight: 100);
      expect(session.attachCount, 2);
      a();
      expect(session.keyboardHeight, 100);
      b();
      expect(session.keyboardHeight, 0);
    });
  });

  group('CyberImeControllerCommit', () {
    test('insert backspace clear', () {
      final ctrl = TextEditingController();
      final commit = CyberImeControllerCommit(ctrl);
      commit.insert('ab');
      expect(ctrl.text, 'ab');
      commit.backspace();
      expect(ctrl.text, 'a');
      commit.clear();
      expect(ctrl.text, '');
    });
  });
}
