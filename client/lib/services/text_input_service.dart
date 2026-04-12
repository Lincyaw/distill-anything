import '../models/event.dart';

/// Service for creating text-based events.
///
/// Handles saving text notes, annotations, and quick entries.
class TextInputService {
  /// Create a text event from user input.
  ///
  /// [content] is the main text body.
  /// [annotation] is an optional short label or tag.
  /// Returns the created [Event].
  Event createTextEvent(String content, {String? annotation}) {
    return Event(
      type: EventType.text,
      textContent: content,
      annotation: annotation,
    );
  }
}
