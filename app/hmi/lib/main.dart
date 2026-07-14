import 'package:flutter/material.dart';
import 'package:lws_hmi/ui/demo/p2_demo_page.dart';

void main() {
  runApp(const LwsHmiApp());
}

class LwsHmiApp extends StatelessWidget {
  const LwsHmiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'lws-hmi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Startup home = P2 demo (no named routes yet).
      home: const P2DemoPage(),
    );
  }
}
