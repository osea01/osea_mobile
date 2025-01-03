import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';


class Distribution {
  static Database? _db;
  static Future<void>? _future;
  
  static void initFuture() {
    _future = _initDB();
  } 

  static Future<void> _initDB() async {
    io.Directory appDir = await getApplicationDocumentsDirectory();
    String dbPath = path.join(appDir.path, "avonet.db");

    bool dbExists = await io.File(dbPath).exists();

    if (!dbExists) {
      ByteData data = await rootBundle.load(path.join("assets", "db", "avonet.db"));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      await io.File(dbPath).writeAsBytes(bytes, flush: true);
    }

    _db = await openDatabase(dbPath);
  }

  static Future<void> closeDB() async {
    await _db!.close();
  }

  static Future<List<int>> query(double lat, double lng) async {
    while (_future == null) {
      initFuture();
    }

    await _future;

    return (await _db!.rawQuery('''
SELECT m.cls
FROM distributions AS d
LEFT OUTER JOIN places AS p
  ON p.worldid = d.worldid
LEFT OUTER JOIN sp_cls_map AS m
  ON d.species = m.species
WHERE p.south <= $lat
  AND p.north >= $lat
  AND p.east >= $lng
  AND p.west <= $lng
GROUP BY d.species, m.cls;
''')).map((m) => int.parse(m['cls'].toString())).toList();
  }

  static Future<List<MapEntry<int, double>>> getFilteredPredictions(List<double> predictions, double lat, double lng) async {
    final original = predictions.asMap();
    final speciesList = await query(lat, lng);
    return original.entries.where((e) => speciesList.contains(e.key)).toList();
  }
}