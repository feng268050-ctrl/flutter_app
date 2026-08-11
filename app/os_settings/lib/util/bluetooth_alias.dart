import 'dart:io';

import 'package:cyber_hal/sys_info.dart';
import 'package:flutter/foundation.dart';

const kBluetoothAliasFile = '/var/lib/bluetooth/adapter-alias';

/// Brand + `" "` + Model from product identity (OS Settings Bluetooth policy).
String bluetoothAliasFromIdentity({
  required String brand,
  required String model,
}) {
  final b = brand.trim();
  final m = model.trim();
  if (b.isNotEmpty && m.isNotEmpty) return '$b $m';
  if (m.isNotEmpty) return m;
  if (b.isNotEmpty) return b;
  return '';
}

String bluetoothAliasFromProduct(ProductInfo product) {
  return bluetoothAliasFromIdentity(brand: product.brand, model: product.model);
}

/// Persists alias for bt-set-alias / BlueZ stack-up readers.
Future<void> persistBluetoothAlias(String alias) async {
  final trimmed = alias.trim();
  if (trimmed.isEmpty) return;
  try {
    final f = File(kBluetoothAliasFile);
    await f.parent.create(recursive: true);
    await f.writeAsString('$trimmed\n', flush: true);
  } catch (e) {
    debugPrint('bluetooth-alias: persist failed: $e');
  }
}

/// Write Brand Model alias from [product] and optionally invoke board helper.
Future<String> applyBluetoothAliasFromProduct(
  ProductInfo product, {
  Future<int> Function(String alias)? setAliasHelper,
}) async {
  final alias = bluetoothAliasFromProduct(product);
  if (alias.isEmpty) return alias;
  await persistBluetoothAlias(alias);
  if (setAliasHelper != null) {
    try {
      await setAliasHelper(alias);
    } catch (e) {
      debugPrint('bluetooth-alias: helper failed: $e');
    }
  }
  return alias;
}
