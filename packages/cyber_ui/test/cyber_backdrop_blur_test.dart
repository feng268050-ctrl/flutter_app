import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blur intensity sigma aligns with lws-ui range', () {
    expect(CyberBlurIntensity.transparent.sigma, 0);
    expect(CyberBlurIntensity.low.sigma, 12);
    expect(CyberBlurIntensity.medium.sigma, 20);
    expect(CyberBlurIntensity.high.sigma, 23);
    expect(CyberBlurIntensity.extreme.sigma, 25);
  });

  test('warm extreme overlay matches lws-ui resolveOverlayColor', () {
    final color = cyberBlurOverlayColor(
      intensity: CyberBlurIntensity.extreme,
      tint: CyberBlurTint.warm,
    );
    expect(color.toARGB32(), 0x50FFFFFF);
  });

  testWidgets('realtime mode uses BackdropFilter by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.blue),
              Center(
                child: SizedBox(
                  width: 120,
                  height: 80,
                  child: CyberBackdropBlur(
                    child: Center(child: Text('glass')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('glass'), findsOneWidget);
  });

  testWidgets('firstFrame without scope falls back to fake glass', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 80,
              child: CyberBackdropBlur(
                sampleMode: CyberBlurSampleMode.firstFrame,
                child: Center(child: Text('frozen')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('frozen'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('onChange re-samples when sampleToken changes', (tester) async {
    var token = 0;
    final controller = CyberBackdropBlurController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CyberBlurBackdropScope(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const CyberBlurBackdropTarget(
                      child: ColoredBox(color: Colors.teal),
                    ),
                    Center(
                      child: SizedBox(
                        width: 100,
                        height: 60,
                        child: CyberBackdropBlur(
                          sampleMode: CyberBlurSampleMode.onChange,
                          sampleToken: token,
                          controller: controller,
                          child: TextButton(
                            onPressed: () {
                              setState(() => token++);
                            },
                            child: Text('t$token'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    expect(find.text('t0'), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pump();
    await tester.pump();
    expect(find.text('t1'), findsOneWidget);

    controller.requestSample();
    await tester.pump();
    await tester.pump();
    expect(find.text('t1'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('firstFrame uses injected backdropScope outside InheritedWidget',
      (tester) async {
    final scopeKey = GlobalKey<CyberBlurBackdropScopeState>();
    Widget buildTree() {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              CyberBlurBackdropScope(
                key: scopeKey,
                child: const CyberBlurBackdropTarget(
                  child: ColoredBox(
                    color: Colors.orange,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 80,
                  width: double.infinity,
                  child: CyberBackdropBlur(
                    sampleMode: CyberBlurSampleMode.firstFrame,
                    backdropScope: scopeKey.currentState,
                    child: const Center(child: Text('kbd')),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTree());
    await tester.pumpWidget(buildTree());
    await tester.pump();
    await tester.pump();

    expect(find.text('kbd'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsOneWidget);
  });

  test('controller generation bumps on requestSample', () {
    final c = CyberBackdropBlurController();
    expect(c.generation, 0);
    c.requestSample();
    expect(c.generation, 1);
    c.dispose();
  });

  testWidgets('followLayout re-crops while list scrolls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberBlurBackdropScope(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CyberBlurBackdropTarget(
                  child: ColoredBox(color: Colors.deepPurple),
                ),
                ListView.builder(
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        height: 80,
                        child: CyberBackdropBlur(
                          sampleMode: CyberBlurSampleMode.followLayout,
                          intensity: CyberBlurIntensity.low,
                          blurTint: CyberBlurTint.dark,
                          child: Center(child: Text('row-$index')),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('row-0'), findsOneWidget);
    expect(find.byType(RawImage), findsWidgets);

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // followLayout keeps the shared pre-blurred RawImage while offset updates.
    expect(find.byType(RawImage), findsWidgets);
  });
}
