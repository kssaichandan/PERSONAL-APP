import 'dart:convert';

String deltaToPlainText(String? deltaJson) {
  if (deltaJson == null || deltaJson.isEmpty) return '';

  try {
    final delta = jsonDecode(deltaJson);
    if (delta is! List) return deltaJson;

    final buffer = StringBuffer();
    for (final op in delta) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert == null) continue;
      if (insert is String) {
        buffer.write(insert);
      } else if (insert is Map) {
        final text = insert['text'] ?? insert['caption'] ?? '';
        buffer.write(text);
      }
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? deltaJson : result;
  } catch (_) {
    return deltaJson;
  }
}
