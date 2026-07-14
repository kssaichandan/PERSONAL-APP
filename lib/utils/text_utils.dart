import 'dart:convert';

String deltaToPlainText(String deltaJson) {
  try {
    final delta = jsonDecode(deltaJson);
    return (delta as List).map((op) => op['insert'] ?? '').join().trim();
  } catch (_) {
    return deltaJson;
  }
}
