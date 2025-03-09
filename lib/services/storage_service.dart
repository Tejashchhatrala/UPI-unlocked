import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/catalog_models.dart';
import 'dart:io';

class StorageService {
  static Database? _database;
  static const String tableName = 'catalog';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'catalog.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id TEXT PRIMARY KEY,
            data TEXT,
            lastUpdated INTEGER
          )
        ''');
      },
    );
  }

  Future<void> saveCatalog(String vendorId, List<Category> categories) async {
    final db = await database;
    final data = {
      'categories': categories.map((c) => c.toMap()).toList(),
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };

    await db.insert(
      tableName,
      {
        'id': vendorId,
        'data': data.toString(),
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Category>?> getCatalog(String vendorId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [vendorId],
    );

    if (maps.isEmpty) return null;

    final data = maps.first['data'] as String;
    // Parse the data and convert to categories
    // You might want to add proper JSON parsing here
    return null; // TODO: Implement proper parsing
  }

  Future<void> saveImage(String imagePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = basename(imagePath);
    final savedPath = join(directory.path, fileName);

    await File(imagePath).copy(savedPath);
  }
}