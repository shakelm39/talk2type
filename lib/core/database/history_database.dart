import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/models/transcription_item.dart';

class HistoryDatabase {
  static final HistoryDatabase instance = HistoryDatabase._init();
  static Database? _database;

  HistoryDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('voiceflow_history.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transcriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        audio_path TEXT,
        mode TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_success INTEGER NOT NULL,
        is_direct_typed INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertItem(TranscriptionItem item) async {
    final db = await instance.database;
    return await db.insert('transcriptions', item.toMap());
  }

  Future<List<TranscriptionItem>> getAllItems() async {
    final db = await instance.database;
    final result = await db.query('transcriptions', orderBy: 'id DESC');
    return result.map((json) => TranscriptionItem.fromMap(json)).toList();
  }

  Future<List<TranscriptionItem>> searchItems(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'transcriptions',
      where: 'text LIKE ? OR mode LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'id DESC',
    );
    return result.map((json) => TranscriptionItem.fromMap(json)).toList();
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'transcriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAll() async {
    final db = await instance.database;
    return await db.delete('transcriptions');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
