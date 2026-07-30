import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Minimal multipart/form-data parser for `POST /v1/videos`.
final class MultipartFormData {
  MultipartFormData({
    required this.fields,
    required this.files,
  });

  final Map<String, String> fields;
  /// Field name → temp file path.
  final Map<String, String> files;

  static Future<MultipartFormData?> parse(HttpRequest request) async {
    final contentType = request.headers.contentType;
    if (contentType == null ||
        contentType.mimeType != 'multipart/form-data') {
      return null;
    }
    final boundary = contentType.parameters['boundary'];
    if (boundary == null || boundary.isEmpty) {
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
    }
    return parseBytes(builder.takeBytes(), boundary);
  }

  static MultipartFormData? parseBytes(Uint8List body, String boundary) {
    final marker = utf8.encode('--$boundary');
    final ranges = <({int start, int end})>[];
    var searchFrom = 0;
    while (true) {
      final at = _indexOf(body, marker, searchFrom);
      if (at < 0) {
        break;
      }
      ranges.add((start: at, end: at + marker.length));
      searchFrom = at + marker.length;
    }
    if (ranges.length < 2) {
      return null;
    }

    final fields = <String, String>{};
    final files = <String, String>{};
    for (var i = 0; i < ranges.length - 1; i++) {
      var partStart = ranges[i].end;
      // Skip CRLF after boundary.
      if (partStart + 1 < body.length &&
          body[partStart] == 13 &&
          body[partStart + 1] == 10) {
        partStart += 2;
      } else if (partStart < body.length && body[partStart] == 10) {
        partStart += 1;
      }
      // Closing `--` after a boundary means end.
      if (partStart + 1 < body.length &&
          body[partStart] == 45 &&
          body[partStart + 1] == 45) {
        break;
      }
      var partEnd = ranges[i + 1].start;
      if (partEnd >= 2 &&
          body[partEnd - 2] == 13 &&
          body[partEnd - 1] == 10) {
        partEnd -= 2;
      } else if (partEnd >= 1 && body[partEnd - 1] == 10) {
        partEnd -= 1;
      }
      if (partEnd <= partStart) {
        continue;
      }
      _parsePart(
        Uint8List.sublistView(body, partStart, partEnd),
        fields,
        files,
      );
    }
    if (fields.isEmpty && files.isEmpty) {
      return null;
    }
    return MultipartFormData(fields: fields, files: files);
  }

  static void _parsePart(
    Uint8List part,
    Map<String, String> fields,
    Map<String, String> files,
  ) {
    var headerEnd = _indexOf(part, utf8.encode('\r\n\r\n'), 0);
    var bodyStart = headerEnd + 4;
    if (headerEnd < 0) {
      headerEnd = _indexOf(part, utf8.encode('\n\n'), 0);
      if (headerEnd < 0) {
        return;
      }
      bodyStart = headerEnd + 2;
    }
    final headerText =
        utf8.decode(part.sublist(0, headerEnd), allowMalformed: true);
    final nameMatch = RegExp(
      r'name="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(headerText);
    if (nameMatch == null) {
      return;
    }
    final name = nameMatch.group(1)!;
    final filenameMatch = RegExp(
      r'filename="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(headerText);
    final content = part.sublist(bodyStart);
    if (filenameMatch != null) {
      final tmp = File(
        '${Directory.systemTemp.path}/lws-upload-'
        '${DateTime.now().microsecondsSinceEpoch}-$name',
      );
      tmp.writeAsBytesSync(content);
      files[name] = tmp.path;
    } else {
      fields[name] =
          utf8.decode(content, allowMalformed: true).trim();
    }
  }

  static int _indexOf(Uint8List data, List<int> pattern, int from) {
    if (pattern.isEmpty || from >= data.length) {
      return -1;
    }
    outer:
    for (var i = from; i <= data.length - pattern.length; i++) {
      for (var j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          continue outer;
        }
      }
      return i;
    }
    return -1;
  }
}
