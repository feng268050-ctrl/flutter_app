import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/presentation/engineer_action_layout.dart';

void main() {
  test('Engineer action group stacks only when Large content cannot fit', () {
    expect(
      EngineerActionLayout.useVertical(
        isLargeText: false,
        maxWidth: 420,
        resetLabelWidth: 180,
        saveLabelWidth: 170,
      ),
      isFalse,
    );
    expect(
      EngineerActionLayout.useVertical(
        isLargeText: true,
        maxWidth: 620,
        resetLabelWidth: 180,
        saveLabelWidth: 170,
      ),
      isFalse,
    );
    expect(
      EngineerActionLayout.useVertical(
        isLargeText: true,
        maxWidth: 500,
        resetLabelWidth: 180,
        saveLabelWidth: 170,
      ),
      isTrue,
    );
  });
}
