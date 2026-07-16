import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showErrorSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  final theme = (context.getElementForInheritedWidgetOfExactType<Theme>()?.widget as Theme?)?.data ?? ThemeData.light();
  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: theme.colorScheme.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

void showSuccessSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  final theme = (context.getElementForInheritedWidgetOfExactType<Theme>()?.widget as Theme?)?.data ?? ThemeData.light();
  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: theme.colorScheme.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

void debugLog(String message) {
  if (kDebugMode) debugPrint(message);
}
