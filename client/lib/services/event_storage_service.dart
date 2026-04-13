import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/event.dart';

/// SQLite-backed storage for events.
///
/// Provides CRUD operations and query capabilities for the events table.
/// Uses singleton pattern to ensure a single database connection.
class EventStorageService {
  static final EventStorageService _instance = EventStorageService._internal();
  factory EventStorageService() => _instance;
  EventStorageService._internal();

  Database? _database;
  Future<void>? _initFuture;

  /// Ensure the database is initialized; safe to call multiple times.
  /// Resets on failure so the next call retries.
  Future<void> _ensureInitialized() async {
    if (_database != null) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }
    _initFuture = init();
    try {
      await _initFuture;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  /// The underlying database instance. Auto-initializes on first access.
  Future<Database> get _db async {
    await _ensureInitialized();
    return _database!;
  }

  /// Initialize the database and create tables if needed.
  Future<void> init() async {
    if (_database != null) return;

    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, 'distill_anything.db');

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// Initialize with a provided database (useful for testing).
  Future<void> initWithDatabase(Database db) async {
    _database = db;
    await _onCreate(db, 1);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        payload_path TEXT,
        text_content TEXT,
        annotation TEXT,
        checksum TEXT,
        upload_status TEXT NOT NULL,
        file_size_bytes INTEGER
      )
    ''');
  }

  /// Insert a new event into the database.
  Future<void> insertEvent(Event event) async {
    final db = await _db;
    await db.insert(
      'events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all events, ordered by timestamp descending.
  /// Optionally filtered by [filterType], with [limit] and [offset].
  Future<List<Event>> getAllEvents({
    EventType? filterType,
    int limit = 100,
    int offset = 0,
  }) async {
    String? where;
    List<Object?>? whereArgs;

    if (filterType != null) {
      where = 'type = ?';
      whereArgs = [filterType.name];
    }

    final db = await _db;
    final maps = await db.query(
      'events',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((m) => Event.fromMap(m)).toList();
  }

  /// Retrieve a single event by [id].
  Future<Event?> getEvent(String id) async {
    final db = await _db;
    final maps = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Event.fromMap(maps.first);
  }

  /// Update an existing event.
  Future<void> updateEvent(Event event) async {
    final db = await _db;
    await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  /// Update just the upload status for an event.
  Future<void> updateUploadStatus(String id, UploadStatus status) async {
    final db = await _db;
    await db.update(
      'events',
      {'upload_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Retrieve events that need uploading (pending or failed).
  Future<List<Event>> getPendingUploads() async {
    final db = await _db;
    final maps = await db.query(
      'events',
      where: 'upload_status = ? OR upload_status = ?',
      whereArgs: [UploadStatus.pending.name, UploadStatus.failed.name],
      orderBy: 'timestamp ASC',
    );

    return maps.map((m) => Event.fromMap(m)).toList();
  }

  /// Delete an event by its [id].
  /// Also deletes the associated payload file if it exists.
  Future<void> deleteEvent(String id) async {
    final db = await _db;
    // Fetch the event first to get the payload path.
    final maps = await db.query(
      'events',
      columns: ['payload_path'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      final payloadPath = maps.first['payload_path'] as String?;
      if (payloadPath != null) {
        final file = File(payloadPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get the total count of events.
  Future<int> getEventCount() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM events');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get the total storage used in bytes (sum of file_size_bytes).
  Future<int> getTotalStorageBytes() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(file_size_bytes), 0) as total FROM events',
    );
    final total = result.first['total'];
    if (total is int) return total;
    return 0;
  }

  /// Delete all events whose upload status is 'uploaded' or 'verified'.
  /// Also deletes associated payload files.
  /// Returns the number of events deleted.
  Future<int> deleteUploadedEvents() async {
    final db = await _db;
    // First get payload paths to delete files
    final maps = await db.query(
      'events',
      columns: ['id', 'payload_path'],
      where: 'upload_status = ? OR upload_status = ?',
      whereArgs: [UploadStatus.uploaded.name, UploadStatus.verified.name],
    );

    // Delete files
    for (final map in maps) {
      final path = map['payload_path'] as String?;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    // Delete from DB
    final count = await db.delete(
      'events',
      where: 'upload_status = ? OR upload_status = ?',
      whereArgs: [UploadStatus.uploaded.name, UploadStatus.verified.name],
    );
    return count;
  }

  /// Close the database connection.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
