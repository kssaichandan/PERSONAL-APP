// Shared utility functions

/// Strips HTML tags and normalizes whitespace from text content
String plainText(String content) {
  return content
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Formats a number with compact notation (e.g., 1.2M, 500K)
String formatCompactNumber(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toString();
}

/// Formats milliseconds into a readable duration string
String formatDuration(int milliseconds) {
  if (milliseconds < 1000) return '${milliseconds}ms';
  final seconds = milliseconds ~/ 1000;
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${minutes}m ${seconds % 60}s';
  final hours = minutes ~/ 60;
  return '${hours}h ${minutes % 60}m';
}