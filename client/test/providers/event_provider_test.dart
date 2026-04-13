import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:distill_anything/models/event.dart';
import 'package:distill_anything/providers/event_provider.dart';
import 'package:distill_anything/services/event_storage_service.dart';

void main() {
  late EventStorageService storage;
  late EventProvider provider;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    storage = EventStorageService();
    // Close any previous DB to reset singleton state
    await storage.close();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await storage.initWithDatabase(db);
    provider = EventProvider(storage: storage);
  });

  tearDown(() async {
    await storage.close();
  });

  group('EventProvider', () {
    test('starts with empty events list', () {
      expect(provider.events, isEmpty);
      expect(provider.totalCount, 0);
    });

    test('addEvent inserts to DB and in-memory list', () async {
      final event = Event(
        id: 'e1',
        type: EventType.text,
        textContent: 'Hello',
      );

      await provider.addEvent(event);

      expect(provider.events.length, 1);
      expect(provider.events.first.id, 'e1');
      expect(provider.totalCount, 1);

      // Verify it's in the DB
      final dbEvent = await storage.getEvent('e1');
      expect(dbEvent, isNotNull);
      expect(dbEvent!.textContent, 'Hello');
    });

    test('loadEvents fetches from DB', () async {
      await storage.insertEvent(Event(id: 'db1', type: EventType.audio));
      await storage.insertEvent(Event(id: 'db2', type: EventType.photo));

      await provider.loadEvents();

      expect(provider.events.length, 2);
    });

    test('updateEvent modifies existing event', () async {
      final event = Event(
        id: 'u1',
        type: EventType.text,
        textContent: 'before',
      );
      await provider.addEvent(event);

      final updated = event.copyWith(textContent: 'after');
      await provider.updateEvent(updated);

      expect(provider.events.first.textContent, 'after');
    });

    test('deleteEvent removes from list and DB', () async {
      await provider.addEvent(Event(id: 'd1', type: EventType.text));
      await provider.addEvent(Event(id: 'd2', type: EventType.text));

      await provider.deleteEvent('d1');

      expect(provider.events.length, 1);
      expect(provider.events.first.id, 'd2');
      expect(await storage.getEvent('d1'), isNull);
    });

    test('setFilter filters events by type', () async {
      await provider.addEvent(Event(id: 'f1', type: EventType.audio));
      await provider.addEvent(Event(id: 'f2', type: EventType.photo));
      await provider.addEvent(Event(id: 'f3', type: EventType.audio));

      provider.setFilter(EventType.audio);
      expect(provider.events.length, 2);
      expect(provider.events.every((e) => e.type == EventType.audio), isTrue);

      provider.setFilter(EventType.photo);
      expect(provider.events.length, 1);

      // Reset to all
      provider.setFilter(null);
      expect(provider.events.length, 3);
    });

    test('filterType returns current filter', () {
      expect(provider.filterType, isNull);
      provider.setFilter(EventType.video);
      expect(provider.filterType, EventType.video);
      provider.setFilter(null);
      expect(provider.filterType, isNull);
    });

    test('pendingUpload returns pending and failed events', () async {
      await provider.addEvent(Event(
        id: 'p1',
        type: EventType.text,
        uploadStatus: UploadStatus.pending,
      ));
      await provider.addEvent(Event(
        id: 'p2',
        type: EventType.text,
        uploadStatus: UploadStatus.uploaded,
      ));
      await provider.addEvent(Event(
        id: 'p3',
        type: EventType.text,
        uploadStatus: UploadStatus.failed,
      ));

      final pending = provider.pendingUpload;
      expect(pending.length, 2);
      expect(pending.map((e) => e.id), containsAll(['p1', 'p3']));
    });
  });
}
