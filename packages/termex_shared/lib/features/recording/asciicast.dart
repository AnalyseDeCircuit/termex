/// asciicast v2 parsing for playback.
///
/// Format: a JSON header object on the first line, then one JSON array per
/// event — `[elapsedSeconds, "o"|"i", data]`. Output events ("o") are what a
/// player replays; input ("i") is recorded for auditing and is not echoed,
/// since the shell already echoed it into the output stream.
library;

import 'dart:convert';

class CastEvent {
  /// Seconds since the recording started.
  final double time;
  final String data;

  const CastEvent(this.time, this.data);
}

class Cast {
  final int width;
  final int height;
  final List<CastEvent> events;

  const Cast({
    required this.width,
    required this.height,
    required this.events,
  });

  /// Timestamp of the final event, or zero for an empty recording.
  Duration get duration => events.isEmpty
      ? Duration.zero
      : Duration(microseconds: (events.last.time * 1e6).round());

  /// Parses [content], skipping anything malformed.
  ///
  /// A recording is written incrementally and may be truncated if the app
  /// died mid-session, so a trailing partial line is expected rather than
  /// exceptional — refusing to parse the whole file over it would lose the
  /// entire session.
  static Cast parse(String content) {
    var width = 80;
    var height = 24;
    final events = <CastEvent>[];
    var seenHeader = false;

    for (final line in const LineSplitter().convert(content)) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (!seenHeader && decoded is Map) {
          width = (decoded['width'] as num?)?.toInt() ?? width;
          height = (decoded['height'] as num?)?.toInt() ?? height;
          seenHeader = true;
          continue;
        }
        if (decoded is List && decoded.length >= 3 && decoded[1] == 'o') {
          events.add(CastEvent(
            (decoded[0] as num).toDouble(),
            decoded[2] as String,
          ));
        }
      } catch (_) {
        // Truncated or corrupt line — keep what parsed.
      }
    }

    return Cast(width: width, height: height, events: events);
  }
}
