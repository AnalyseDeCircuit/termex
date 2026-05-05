/// asciicast v2 format parser and generator (v0.47 spec §5.2).
///
/// v2 format:
///   Line 1 – header JSON: {"version":2,"width":80,"height":24,...}
///   Line 2+ – event JSON arrays: [<time>, "<type>", "<data>"]
///   type is "o" (output) or "i" (input)
library;

import 'dart:convert';

// ─── Header ───────────────────────────────────────────────────────────────────

class AsciicastHeader {
  final int version;
  final int width;
  final int height;
  final double? duration;
  final String? title;
  final Map<String, String> env;

  const AsciicastHeader({
    this.version = 2,
    required this.width,
    required this.height,
    this.duration,
    this.title,
    this.env = const {},
  });

  factory AsciicastHeader.fromJson(Map<String, dynamic> json) {
    return AsciicastHeader(
      version: (json['version'] as num?)?.toInt() ?? 2,
      width: (json['width'] as num?)?.toInt() ?? 80,
      height: (json['height'] as num?)?.toInt() ?? 24,
      duration: (json['duration'] as num?)?.toDouble(),
      title: json['title'] as String?,
      env: (json['env'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'width': width,
        'height': height,
        if (duration != null) 'duration': duration,
        if (title != null) 'title': title,
        if (env.isNotEmpty) 'env': env,
      };
}

// ─── Event ────────────────────────────────────────────────────────────────────

class AsciicastEvent {
  /// Time offset in seconds from recording start.
  final double time;

  /// 'o' = terminal output, 'i' = terminal input.
  final String type;

  /// Raw text data.
  final String data;

  const AsciicastEvent({
    required this.time,
    required this.type,
    required this.data,
  });

  factory AsciicastEvent.fromJson(List<dynamic> json) {
    return AsciicastEvent(
      time: (json[0] as num).toDouble(),
      type: json[1] as String,
      data: json[2] as String,
    );
  }

  List<dynamic> toJson() => [time, type, data];

  bool get isOutput => type == 'o';
}

// ─── File ─────────────────────────────────────────────────────────────────────

class AsciicastFile {
  final AsciicastHeader header;
  final List<AsciicastEvent> events;

  const AsciicastFile({required this.header, required this.events});

  /// Total duration in seconds (uses header field, or last event timestamp).
  double get duration {
    if (header.duration != null) return header.duration!;
    return events.isEmpty ? 0.0 : events.last.time;
  }

  /// Serialises to asciicast v2 NDJSON string.
  String encode() {
    final buf = StringBuffer();
    buf.writeln(jsonEncode(header.toJson()));
    for (final e in events) {
      buf.writeln(jsonEncode(e.toJson()));
    }
    return buf.toString();
  }

  /// Parses an asciicast v2 NDJSON string.
  ///
  /// Throws [FormatException] when the header is missing or malformed.
  static AsciicastFile decode(String ndjson) {
    final lines = ndjson
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) throw const FormatException('empty asciicast file');

    final headerRaw = jsonDecode(lines.first);
    if (headerRaw is! Map<String, dynamic>) {
      throw const FormatException('asciicast header must be a JSON object');
    }
    final header = AsciicastHeader.fromJson(headerRaw);

    final events = <AsciicastEvent>[];
    for (var i = 1; i < lines.length; i++) {
      final dynamic raw;
      try {
        raw = jsonDecode(lines[i]);
      } catch (_) {
        continue;
      }
      if (raw is! List || raw.length < 3) continue;
      events.add(AsciicastEvent.fromJson(raw));
    }

    return AsciicastFile(header: header, events: events);
  }

  /// Returns only output events visible in the terminal at [atSeconds].
  List<AsciicastEvent> visibleAt(double atSeconds) =>
      events.where((e) => e.isOutput && e.time <= atSeconds).toList();
}
