import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/hal/hal_assets.dart';
import 'package:lws_hmi/ui/demo/p2_demo_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final profile = await BoardProfile.loadAsset(HmiHalAssets.boardProfile);
  runApp(LwsHmiApp(boardProfile: profile));
}

class LwsHmiApp extends StatelessWidget {
  const LwsHmiApp({super.key, required this.boardProfile});

  final BoardProfile boardProfile;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HMI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Startup home = P2 demo (no named routes yet).
      home: P2DemoPage(boardProfile: boardProfile),
    );
  }
}
