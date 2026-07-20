import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter_test/flutter_test.dart';

final class _CountingClick implements CyberClickSound {
  int calls = 0;

  @override
  Future<void> playClick() async {
    calls++;
  }
}

void main() {
  tearDown(() {
    CyberClickSoundRegistry.register(null);
  });

  test('playClick is no-op when unregistered', () {
    CyberClickSoundRegistry.register(null);
    expect(() => CyberClickSoundRegistry.playClick(), returnsNormally);
  });

  test('playClick delegates to registered backend', () async {
    final backend = _CountingClick();
    CyberClickSoundRegistry.register(backend);
    CyberClickSoundRegistry.playClick();
    await Future<void>.delayed(Duration.zero);
    expect(backend.calls, 1);
  });
}
