import 'package:flutter/material.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const HelloHomePage(),
    );
  }
}

class HelloHomePage extends StatelessWidget {
  const HelloHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Hello, lws-hmi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
