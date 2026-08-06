import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/app_routes.dart';

void main() {
  test('generateAppInitialRoutes emits only Safety Tips, not Home under it', () {
    final routes = generateAppInitialRoutes(
      AppRoutes.safetyTips,
      (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text(settings.name ?? ''),
        );
      },
    );

    expect(routes, hasLength(1));
    expect(routes.single.settings.name, AppRoutes.safetyTips);
  });

  test('generateAppInitialRoutes emits only Home when asked', () {
    final routes = generateAppInitialRoutes(
      AppRoutes.home,
      (settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text(settings.name ?? ''),
        );
      },
    );

    expect(routes, hasLength(1));
    expect(routes.single.settings.name, AppRoutes.home);
  });
}
