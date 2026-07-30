import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/statistics/infrastructure/legacy_static_data_reader.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('reads only unit-safe values from the legacy static_data row', () async {
    final directory = await Directory.systemTemp.createTemp('legacy-stats');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/lws-ui-static-data.db';
    final db = sqlite3.open(path);
    try {
      db.execute('''
CREATE TABLE static_data (
  weldingTimeLength INTEGER NOT NULL,
  cuttingTimeLength INTEGER NOT NULL,
  washTimeLength INTEGER NOT NULL,
  jobTimeLength INTEGER NOT NULL,
  consumableTimeLength INTEGER NOT NULL,
  commonUse INTEGER,
  currStartTime INTEGER,
  topStartTime INTEGER,
  currDay TEXT,
  topDay TEXT
)
''');
      db.execute('''
INSERT INTO static_data VALUES (12, 8, 4, 30, 900, 2, 100, 50, 'Monday', 'Monday')
''');
    } finally {
      db.dispose();
    }

    final legacy = await LegacyStaticDataReader.readFile(path);

    expect(legacy, isNotNull);
    expect(legacy!.weldSecondsTotal, 12);
    expect(legacy.cutSecondsTotal, 8);
    expect(legacy.cleanSecondsTotal, 4);
    expect(legacy.jobRuntimeSecondsTotal, 30);
    expect(legacy.favoriteMaterialType, 2);
    expect(legacy.wireFeedLengthMmTotal, isNull);
    expect(legacy.weekAnchorStartedAtMs, isNull);
  });
}
