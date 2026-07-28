import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/infrastructure/sqlite_process_library_repository.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:sqlite3/sqlite3.dart';

Future<ProcessLibraryController> createEmptyProcessLibraryController(
  WidgetTester tester,
) async {
  final database = sqlite3.openInMemory();
  addTearDown(database.dispose);
  final repository = SqliteProcessLibraryRepository(database: database);
  final controller = ProcessLibraryController(
    repository: repository,
    importer: ProcessLibraryImporter(
      repository: repository,
      deviceModel: 'ynh960',
      manifestAsset: 'manifest.json',
      bundle: _EmptyManifestBundle(),
    ),
    applier: ProcessParameterApplier(
      modbus: _UnusedModbus(),
      interlockFailure: () async => ProcessApplyFailure.unsafeMachineState,
    ),
  );
  addTearDown(controller.close);
  return controller;
}

Widget wrapWithProcessLibrary(
  ProcessLibraryController controller,
  Widget child,
) {
  return ProcessLibraryScope(controller: controller, child: child);
}

final class _EmptyManifestBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(
      utf8.encode('{"schema_version":1,"libraries":[]}'),
    );
    return ByteData.sublistView(bytes);
  }
}

final class _UnusedModbus extends ModbusRtuClient {}
