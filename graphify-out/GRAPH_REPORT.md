# Graph Report - .  (2026-07-14)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 481 nodes · 679 edges · 20 communities (19 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0c6e5632`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- habits.dart
- settings.dart
- widget_test.dart
- calendar.dart
- settings_provider.dart
- notes.dart
- calculator.dart
- life.dart
- notification_service.dart
- main.dart
- StatelessWidget
- State
- database.dart
- biometric_service.dart
- CalendarProvider
- MainActivity

## God Nodes (most connected - your core abstractions)
1. `LifeProvider` - 13 edges
2. `SettingsProvider` - 12 edges
3. `CalendarProvider` - 11 edges
4. `HabitsProvider` - 10 edges
5. `NotesProvider` - 10 edges
6. `CalculatorProvider` - 9 edges
7. `_DataSectionState` - 9 edges
8. `_importData` - 7 edges
9. `_confirmClearAllData` - 7 edges
10. `NotificationService` - 7 edges

## Surprising Connections (you probably didn't know these)
- `MockAppDatabase` --implements--> `AppDatabase`  [EXTRACTED]
  test/provider_test.dart → lib/database.dart
- `MockAppDatabase` --implements--> `AppDatabase`  [EXTRACTED]
  test/widget_test.dart → lib/database.dart
- `MockNotificationService` --implements--> `NotificationService`  [EXTRACTED]
  test/provider_test.dart → lib/services/notification_service.dart
- `MockNotificationService` --implements--> `NotificationService`  [EXTRACTED]
  test/widget_test.dart → lib/services/notification_service.dart
- `_confirmClearHistory` --references--> `CalculatorProvider`  [EXTRACTED]
  lib/features/settings.dart → lib/features/calculator.dart

## Import Cycles
- None detected.

## Communities (20 total, 1 thin omitted)

### Community 0 - "habits.dart"
Cohesion: 0.03
Nodes (72): dart:async, _allIconKeys, _buildEmptyState, clearSelection, color, _colorPresets, completionsInMonth, completionsInWeek (+64 more)

### Community 1 - "settings.dart"
Cohesion: 0.07
Nodes (46): calculator.dart, calendar.dart, ChangeNotifier, habits.dart, IconData, CalculatorProvider, build, HabitsProvider (+38 more)

### Community 2 - "widget_test.dart"
Cohesion: 0.07
Nodes (40): main, AppDatabase, NotificationService, prefs, serviceLocator, setupServiceLocator, Mock, MockAppDatabase (+32 more)

### Community 3 - "calendar.dart"
Cohesion: 0.05
Nodes (43): CalendarEvent, category, _categoryFilter, clearCategoryFilter, clearSearch, createState, _currentMonth, date (+35 more)

### Community 4 - "settings_provider.dart"
Cohesion: 0.05
Nodes (40): bool get, Color, Color get, dart:convert, _colorSeed, _copyOnTap, _customCategories, _eventRemindersEnabled (+32 more)

### Community 5 - "notes.dart"
Cohesion: 0.05
Nodes (38): int?, build, _buildList, clearSelection, content, _controller, copyWith, createdAt (+30 more)

### Community 6 - "calculator.dart"
Cohesion: 0.06
Nodes (35): dart:math, double get, build, calc, clearHistory, _error, _evaluate, _expr (+27 more)

### Community 7 - "life.dart"
Cohesion: 0.06
Nodes (31): DateTime, DateTime get, int get, _authenticated, _biometricEnabled, _biometricsAvailable, _checkBiometricsAvailable, child (+23 more)

### Community 8 - "notification_service.dart"
Cohesion: 0.07
Nodes (28): @pragma, ../database.dart, FlutterLocalNotificationsPlugin, FlutterLocalNotificationsPlugin get, cancel, cancelEventNotification, cancelHabitNotification, cancelNoteNotification (+20 more)

### Community 9 - "main.dart"
Cohesion: 0.08
Nodes (22): features/calculator.dart, features/calendar.dart, features/habits.dart, features/life.dart, features/notes.dart, features/settings.dart, ../features/settings_provider.dart, build (+14 more)

### Community 10 - "StatelessWidget"
Cohesion: 0.11
Nodes (19): _ButtonGrid, CalculatorScreen, _DisplayArea, _MemoryRow, _ScientificToggle, _DayNames, _MonthGrid, _MonthHeader (+11 more)

### Community 11 - "State"
Cohesion: 0.20
Nodes (14): _HabitIconPicker, _HabitIconPickerState, HabitsScreen, _HabitsScreenState, _BiometricGuard, _BiometricGuardState, NoteEditorScreen, _NoteEditorScreenState (+6 more)

### Community 12 - "database.dart"
Cohesion: 0.15
Nodes (12): clearInstanceForTesting, _db, _init, _instance, setInstanceForTesting, _testInstance, package:path/path.dart, package:sqflite/sqflite.dart (+4 more)

### Community 13 - "biometric_service.dart"
Cohesion: 0.22
Nodes (8): _auth, authenticate, authenticateWithBiometrics, BiometricService, canAuthenticate, getAvailableBiometrics, LocalAuthentication, package:local_auth/local_auth.dart

### Community 14 - "CalendarProvider"
Cohesion: 0.29
Nodes (7): build, CalendarProvider, CalendarScreen, _CalendarScreenState, EventEditor, _EventEditorState, save

## Knowledge Gaps
- **290 isolated node(s):** `main`, `_instance`, `_db`, `_testInstance`, `setInstanceForTesting` (+285 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NotificationService` connect `widget_test.dart` to `habits.dart`, `main.dart`, `calendar.dart`, `notification_service.dart`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Why does `AppDatabase` connect `widget_test.dart` to `database.dart`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Why does `HabitsProvider` connect `settings.dart` to `habits.dart`, `widget_test.dart`, `State`?**
  _High betweenness centrality (0.023) - this node is a cross-community bridge._
- **What connects `main`, `_instance`, `_db` to the rest of the system?**
  _290 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `habits.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0273972602739726 - nodes in this community are weakly interconnected._
- **Should `settings.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.06845513413506013 - nodes in this community are weakly interconnected._
- **Should `widget_test.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.07399577167019028 - nodes in this community are weakly interconnected._