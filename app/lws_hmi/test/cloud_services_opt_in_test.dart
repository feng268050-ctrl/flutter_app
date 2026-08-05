import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/presentation/pages/cloud_services_settings_page.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/l10n/app_localizations_en.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';

void main() {
  late Directory dir;
  late CloudSettingsStore store;
  final l10n = AppLocalizationsEn();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cloud-services-summary-');
    store = CloudSettingsStore(preferencePath: '${dir.path}/cloud-settings.json')
      ..warmRead();
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('network summary reflects independent plane toggles', () async {
    expect(cloudServicesNetworkSummary(l10n, store), l10n.offLabel);

    await store.setCloudServicesEnabled(true);
    expect(cloudServicesNetworkSummary(l10n, store), l10n.cloudServicesSummaryCloud);

    await store.setLanEnhancementEnabled(true);
    expect(cloudServicesNetworkSummary(l10n, store), l10n.cloudServicesSummaryBoth);

    await store.setCloudServicesEnabled(false);
    expect(cloudServicesNetworkSummary(l10n, store), l10n.cloudServicesSummaryLan);
  });

  test('AppLocalizations exposes cloud services strings', () {
    expect(l10n.cloudServicesText, isNotEmpty);
    expect(l10n.lanEnhancementText, isNotEmpty);
    expect(l10n.cloudServicesFooter, contains('Worker'));
    expect(l10n.lanEnhancementFooter, contains('5580'));
  });
}
