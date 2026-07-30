import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/device_registration/device_registration_dialogs.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_ids.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_scope.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('locked preference isLocked', () async {
    final tmp = await Directory.systemTemp.createTemp('remote-lock-entry-');
    addTearDown(() => tmp.delete(recursive: true));
    final path = '${tmp.path}/remote-lock.json';
    await File(path).writeAsString('{"locked": true}\n');
    final lock = DeviceRemoteLockStore(preferencePath: path)..warmRead();
    expect(lock.isLocked, isTrue);
  });

  testWidgets('confirmNotLocked unlocked short-circuit', (tester) async {
    final path =
        '${Directory.systemTemp.path}/remote-lock-missing-${identityHashCode(Object())}.json';
    final lock = DeviceRemoteLockStore(preferencePath: path)..warmRead();
    expect(lock.isLocked, isFalse);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(key: Key('host'))),
      ),
    );

    final context = tester.element(find.byKey(const Key('host')));
    final ok = await DeviceRegistrationDialogs.confirmNotLocked(context, lock);
    expect(ok, isTrue);
  });

  testWidgets('confirmNotLocked enqueues and auto-closes on unlock', (tester) async {
    // Sync IO: async File writes hang under testWidgets fake-async.
    final path =
        '${Directory.systemTemp.path}/remote-lock-auto-${identityHashCode(Object())}.json';
    File(path).writeAsStringSync('{"locked": true}\n');
    addTearDown(() {
      try {
        File(path).deleteSync();
      } catch (_) {}
    });
    final lock = DeviceRemoteLockStore(preferencePath: path)..warmRead();
    expect(lock.isLocked, isTrue);

    final navKey = GlobalKey<NavigatorState>();
    final queue = GlobalPromptQueue(navigatorKey: navKey);

    await tester.pumpWidget(
      GlobalPromptScope(
        queue: queue,
        child: MaterialApp(
          navigatorKey: navKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: SizedBox(key: Key('host'))),
        ),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byKey(const Key('host')));
    final result = DeviceRegistrationDialogs.confirmNotLocked(
      context,
      lock,
      queue: queue,
      useFakeGlass: true,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Device Locked'), findsOneWidget);
    expect(queue.showingId, GlobalPromptIds.remoteLock);

    // setLocked writes async — run under real async binding.
    await tester.runAsync(() => lock.setLocked(false));
    await tester.pump(); // post-frame dismiss
    await tester.pump(); // pop
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Device Locked'), findsNothing);
    expect(await result.timeout(const Duration(seconds: 2)), isTrue);
  });

  testWidgets('pushNamedIfUnlocked navigates when unlocked', (tester) async {
    final path =
        '${Directory.systemTemp.path}/remote-lock-missing-nav-${identityHashCode(Object())}.json';
    final lock = DeviceRemoteLockStore(preferencePath: path)..warmRead();
    final navKey = GlobalKey<NavigatorState>();
    final queue = GlobalPromptQueue(navigatorKey: navKey);

    await tester.pumpWidget(
      GlobalPromptScope(
        queue: queue,
        child: MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  key: const Key('go'),
                  onPressed: () {
                    DeviceRegistrationDialogs.pushNamedIfUnlocked(
                      context,
                      '/quick',
                      lockStore: lock,
                      queue: queue,
                    );
                  },
                  child: const Text('go'),
                );
              },
            ),
          ),
          routes: {
            '/quick': (_) => const Scaffold(body: Text('quick-mode')),
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('quick-mode'), findsOneWidget);

    Navigator.of(tester.element(find.text('quick-mode'))).pop();
    await tester.pump();
  });
}
