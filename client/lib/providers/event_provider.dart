import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../services/event_storage_service.dart';

/// Manages the list of recorded events.
class EventProvider extends ChangeNotifier {
  final EventStorageService _storage;
  List<Event> _events = [];
  EventType? _filterType;
  bool _isLoading = false;

  EventProvider({EventStorageService? storage})
      : _storage = storage ?? EventStorageService();

  List<Event> get events {
    if (_filterType != null) {
      return _events.where((e) => e.type == _filterType).toList();
    }
    return List.unmodifiable(_events);
  }

  EventType? get filterType => _filterType;
  int get totalCount => _events.length;
  bool get isLoading => _isLoading;

  /// Load all events from the database.
  Future<void> loadEvents() async {
    _isLoading = true;
    notifyListeners();

    _events = await _storage.getAllEvents();

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new event.
  Future<void> addEvent(Event event) async {
    await _storage.insertEvent(event);
    _events.insert(0, event);
    notifyListeners();
  }

  /// Update an existing event (e.g., upload status change).
  Future<void> updateEvent(Event event) async {
    await _storage.updateEvent(event);
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      _events[index] = event;
      notifyListeners();
    }
  }

  /// Delete an event by id.
  Future<void> deleteEvent(String id) async {
    await _storage.deleteEvent(id);
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Filter events by type.
  void setFilter(EventType? type) {
    _filterType = type;
    notifyListeners();
  }

  /// Get events that need uploading.
  List<Event> get pendingUpload => _events
      .where((e) =>
          e.uploadStatus == UploadStatus.pending ||
          e.uploadStatus == UploadStatus.failed)
      .toList();
}
