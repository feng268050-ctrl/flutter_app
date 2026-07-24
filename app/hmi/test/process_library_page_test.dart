import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/infrastructure/sqlite_process_library_repository.dart';
import 'package:lws_hmi/features/process_library/presentation/process_library_page.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  testWidgets('quick mode explains an empty compatible library',
      (tester) async {
    final database = sqlite3.openInMemory();
    final repository = SqliteProcessLibraryRepository(database: database);
    final controller = ProcessLibraryController(
      repository: repository,
      importer: ProcessLibraryImporter(
        repository: repository,
        deviceModel: 'ynh960',
        manifestAsset: 'manifest.json',
        bundle: _ManifestBundle(),
      ),
      applier: ProcessParameterApplier(
        modbus: _UnusedModbus(),
        isSafeToApply: () async => false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessLibraryScope(
          controller: controller,
          child: const ProcessLibraryPage(
            mode: ProcessLibraryPageMode.quick,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('No compatible quick-mode process library is installed.'),
      findsOneWidget,
    );

    await controller.close();
    database.dispose();
  });
}

final class _ManifestBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(
      utf8.encode('{"schema_version":1,"libraries":[]}'),
    );
    return ByteData.sublistView(bytes);
  }
}

final class _UnusedModbus extends ModbusRtuClient {}
