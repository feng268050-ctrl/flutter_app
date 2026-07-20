import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app.dart';
import 'package:lws_hmi/hal/hal_assets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final profile = await BoardProfile.loadAsset(HmiHalAssets.boardProfile);
  runApp(LwsHmiApp(boardProfile: profile));
}
