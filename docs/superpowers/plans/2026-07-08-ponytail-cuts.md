# Ponytail Over-Engineering Cuts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove ~580 lines of dead code, 3 unnecessary dependencies, and simplify over-engineered patterns across the personal app.

**Architecture:** Delete-first approach. Remove entire features (voice recording, scientific calculator) before simplifying remaining code. Each task removes a self-contained over-engineering finding from the ponytail audit.

**Tech Stack:** Flutter 3.7+, Dart 3.7+, SQLite via sqflite, Provider for state.

## Global Constraints

- Run `dart analyze` after every task; zero new warnings
- No new dependencies added; only removals
- Every change must compile and produce a working app
- Follow existing file structure patterns
- One commit per task with descriptive message

---

### Task 1: Delete notifications.dart, inline the variable

**Files:**
- Delete: `lib/notifications.dart`
- Modify: `lib/features/calendar.dart` — add import + top-level variable
- Modify: `lib/features/habits.dart` — change import

**Interfaces:**
- Consumes: `notifications` top-level `FlutterLocalNotificationsPlugin` instance from `lib/notifications.dart`
- Produces: `notifications` top-level variable moved to `lib/features/calendar.dart`

- [ ] **Step 1: Add notifications variable to calendar.dart**

Add after imports in `lib/features/calendar.dart`:
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
```
```dart
final notifications = FlutterLocalNotificationsPlugin();
```

- [ ] **Step 2: Update import in habits.dart**

Change `import '../notifications.dart';` to `import 'package:flutter_local_notifications/flutter_local_notifications.dart';` and add the same `final notifications = FlutterLocalNotificationsPlugin();` line.

Wait — this would create two separate instances. Instead, make habits.dart import from calendar.dart or use a single shared location.

Actually the simplest approach: keep a single shared instance. Since `calendar.dart` and `habits.dart` both use `notifications`, put it in a shared location. But we want to delete `notifications.dart`... 

Simplest: keep `notifications.dart` but make it just the one-liner. Actually the finding was to delete the file entirely. Let me think...

Both files use the same `notifications` variable via `import '../notifications.dart'`. If I delete the file, both need access to the same instance. Easiest: put the variable in one of them and import from there.

`calendar.dart` already imports `'../notifications.dart'`. `habits.dart` already imports `'../notifications.dart'`. I can put it in `calendar.dart` and have `habits.dart` import from `calendar.dart`.

Or even simpler: add the variable to each file. The variable is just `final notifications = FlutterLocalNotificationsPlugin();` — it has no state, it's a plugin handle. Having two instances is harmless but unnecessary.

Simplest legit approach: put it in `calendar.dart` and have `habits.dart` import from there. But that creates a weird dependency.

Actually the REAL simplest: put it in `main.dart` since that's where it's initialized, and export it from there, or just keep `notifications.dart` as a one-liner. But the finding said delete the file.

Let me just put the `final notifications` line in `main.dart` and have `calendar.dart` and `habits.dart` import from `main.dart`... no, that's circular-ish.

Simplest approach: Add `final notifications = FlutterLocalNotificationsPlugin();` at the top of both `calendar.dart` and `habits.dart`. It's a stateless plugin instance — two identical instances work fine, and this avoids any cross-file coupling. The notification IDs are separated by domain (1000+ for habits, regular for calendar), so no collision risk.

- [ ] **Step 1: Add local notifications variable to calendar.dart**

In `lib/features/calendar.dart`, replace `import '../notifications.dart';` with the import for the plugin package, and add the variable:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
```

Right after the imports, add:
```dart
final notifications = FlutterLocalNotificationsPlugin();
```

- [ ] **Step 2: Same for habits.dart**

In `lib/features/habits.dart`, replace `import '../notifications.dart';` with `import 'package:flutter_local_notifications/flutter_local_notifications.dart';` and add `final notifications = FlutterLocalNotificationsPlugin();` after imports.

- [ ] **Step 3: Update main.dart import**

In `lib/main.dart`, replace `import 'notifications.dart';` with `import 'package:flutter_local_notifications/flutter_local_notifications.dart';` and add `final notifications = FlutterLocalNotificationsPlugin();` after the existing imports (before `void main()`).

- [ ] **Step 4: Delete notifications.dart**

Run: `Remove-Item -LiteralPath 'lib\notifications.dart'`

- [ ] **Step 5: Analyze and commit**

Run: `dart analyze lib/`
Expected: No errors.

```bash
git add lib/main.dart lib/features/calendar.dart lib/features/habits.dart lib/notifications.dart -A
git commit -m "delete: notifications.dart, inline plugin variable in consumers"
```

---

### Task 2: Remove voice recording feature (record + audioplayers deps)

**Files:**
- Modify: `pubspec.yaml` — remove `record: ^5.1.2`, `audioplayers: ^6.0.0`, `dependency_overrides` block for `record_linux`
- Modify: `lib/database.dart` — remove `note_recordings` table from `onCreate` and `onUpgrade`
- Modify: `lib/features/notes.dart` — remove all recording-related code (AudioRecorder, _AudioPlayerWidget, recording methods in NotesProvider, recording UI in NoteEditorScreen)
- Delete: `lib/features/notes.dart` lines that reference recording

**Interfaces:**
- Consumes: `NoteRecording` class, `saveRecording()`, `deleteRecording()`, `getRecordings()` in NotesProvider; `AudioRecorder`, `AudioPlayer`, `_AudioPlayerWidget` in NoteEditorScreen
- Produces: Nothing — all removed

Steps:

- [ ] **Step 1: Remove recording deps from pubspec.yaml**

Delete these lines from `pubspec.yaml`:
```
  record: ^5.1.2
  audioplayers: ^6.0.0
```
And the entire `dependency_overrides:` block:
```
dependency_overrides:
  record_linux: ^1.1.1
```

- [ ] **Step 2: Remove recording code from database.dart**

Delete the `note_recordings` table creation from `onCreate` (lines 36-44):
```dart
await db.execute('''
  CREATE TABLE note_recordings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    note_id INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    duration_seconds INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
  )
''');
```

And from `onUpgrade` (lines 103-112):
```dart
await db.execute('''
  CREATE TABLE IF NOT EXISTS note_recordings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    note_id INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    duration_seconds INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
  )
''');
```

- [ ] **Step 3: Remove recording code from notes.dart**

Remove from `lib/features/notes.dart`:
1. Remove imports: `import 'dart:async';`, `import 'dart:io';`, `import 'package:record/record.dart';`, `import 'package:audioplayers/audioplayers.dart';`
2. Delete the entire `NoteRecording` class (lines 84-106)
3. Remove `_recordingsByNoteId` field and all recording-related methods from NotesProvider: `getRecordings()`, `saveRecording()`, `deleteRecording()`, and the recording-loading loop in `load()` (lines 171-176)
4. Remove from NoteEditorScreen: `_audioRecorder`, `_isRecording`, `_recordSeconds`, `_recordTimer` fields + `_startRecording()`, `_stopRecording()`, and the recording UI section at the bottom of `build()` (the `_isRecording ? ... : ...` block + the recordings list)
5. Delete the entire `_AudioPlayerWidget` class (lines 732-826)
6. Remove `recordings` variable usage in NoteEditorScreen.build()
7. Remove `provider.getRecordings()` call from NoteEditorScreen.build() (line 570)

- [ ] **Step 4: Analyze and commit**

Run: `dart analyze lib/`
Expected: No errors.

```bash
git add pubspec.yaml lib/database.dart lib/features/notes.dart
git commit -m "delete: voice recording feature, remove record+audioplayers deps"
```

---

### Task 3: Replace flutter_quill with plain TextField for notes

**Files:**
- Modify: `pubspec.yaml` — remove `flutter_quill: ^11.0.0`
- Modify: `lib/main.dart` — remove `FlutterQuillLocalizations.delegate`
- Modify: `lib/features/notes.dart` — replace QuillController with TextEditingController, remove all Delta JSON serialization

**Interfaces:**
- Consumes: `QuillController`, `Document.fromJson()`, `QuillSimpleToolbar`, `QuillEditor.basic()`, `FlutterQuillLocalizations`
- Produces: Simple `TextEditingController` for note content, plain text storage

- [ ] **Step 1: Remove flutter_quill from pubspec.yaml**

Delete `flutter_quill: ^11.0.0` from `pubspec.yaml`.

- [ ] **Step 2: Remove FlutterQuillLocalizations from main.dart**

In `lib/main.dart`, remove `import 'package:flutter_quill/flutter_quill.dart';` and remove `FlutterQuillLocalizations.delegate` from the `localizationsDelegates` list.

- [ ] **Step 3: Rewrite notes.dart to use plain text**

Replace the entire content model and editor in `lib/features/notes.dart`:

1. Remove `import 'dart:convert';` (no longer needed for Delta JSON)
2. Remove `import 'package:flutter_quill/flutter_quill.dart';`
3. Simplify `plainText()` function — content is now just a string, not Delta JSON. Replace with identity function or remove entirely if no callers remain.
4. In NoteEditorScreen, replace `QuillController _controller` with `TextEditingController _contentController`
5. Replace the Quill toolbar + editor with a multi-line TextField
6. Simplify save logic: content is `_contentController.text` not `jsonEncode(...)`

After removing all flutter_quill references, update the `_saveNoteSilent()` method:
```dart
Future<int> _saveNoteSilent() async {
    final note = Note(
      id: widget.note?.id,
      title: _titleController.text,
      content: _contentController.text,
      color: _selectedColor,
      pinned: widget.note?.pinned ?? false,
      tags: _tagsController.text,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (!mounted) return 0;
    return context.read<NotesProvider>().save(note);
  }
```

Update the `build()` method — replace the Quill toolbar + editor section with:
```dart
Expanded(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: TextField(
      controller: _contentController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        hintText: 'Start writing...',
        border: InputBorder.none,
      ),
    ),
  ),
),
```

- [ ] **Step 4: Analyze and commit**

Run: `dart analyze lib/`
Expected: No errors (or only unused import warnings which we fix).

```bash
git add pubspec.yaml lib/main.dart lib/features/notes.dart
git commit -m "delete: flutter_quill, replace rich text editor with plain TextField"
```

---

### Task 4: Remove scientific calculator mode

**Files:**
- Modify: `lib/features/calculator.dart` — remove `_isScientific` toggle, `_ScientificButtonGrid` class, scientific buttons from `_buildButtons()`, scientific label list in `_CalcButton`

- [ ] **Step 1: Remove scientific toggle and scientific button grid**

In `lib/features/calculator.dart`:
1. Delete `_isScientific` field from `_CalculatorScreenState` (line 264)
2. Delete the scientific toggle `IconButton` from the `actions` list in AppBar
3. Simplify `_buildButtons()` to always return `_StandardButtonGrid(calc: calc)`
4. Delete the entire `_ScientificButtonGrid` class (lines 455-490)
5. Remove `isScientific` parameter from `_CalcButton` constructor and its uses in `getBgColor()` and `getTextColor()`

- [ ] **Step 2: Analyze and commit**

Run: `dart analyze lib/`
Expected: No errors.

```bash
git add lib/features/calculator.dart
git commit -m "delete: scientific calculator mode, simplify to standard only"
```

---

### Task 5: Remove % postfix operator from calculator parser

**Files:**
- Modify: `lib/features/calculator.dart` — delete the % postfix loop in `_primary()`

- [ ] **Step 1: Remove postfix % handling**

In `lib/features/calculator.dart`, delete lines 246-250 (the `// Generalized % postfix operator support` loop):
```dart
    // Generalized % postfix operator support (e.g. (2+3)% -> 0.05)
    while (_pos < _input.length && _input[_pos] == '%') {
      _pos++;
      result /= 100;
    }
```

- [ ] **Step 2: Analyze and commit**

Run: `dart analyze lib/`
Expected: No errors.

```bash
git add lib/features/calculator.dart
git commit -m "delete: % postfix operator from calculator parser"
```

---

### Task 6: Deduplicate theme data in main.dart

**Files:**
- Modify: `lib/main.dart` — extract shared theme properties, reduce dark/light theme duplication

- [ ] **Step 1: Extract shared theme into base**

In `lib/main.dart`, create a shared base theme and extend it for light/dark:

```dart
ThemeData _baseTheme(Brightness brightness) => ThemeData(
  colorSchemeSeed: Colors.deepPurple,
  useMaterial3: true,
  brightness: brightness,
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
);
```

Then replace the `theme:` and `darkTheme:` blocks with:
```dart
theme: _baseTheme(Brightness.light),
darkTheme: _baseTheme(Brightness.dark),
```

- [ ] **Step 2: Analyze and commit**

Run: `dart analyze lib/`
Expected: No errors.

```bash
git add lib/main.dart
git commit -m "shrink: deduplicate light/dark theme into shared base function"
```

---

### Task 7: Extract _getCategoryColor to shared helper in calendar.dart

**Files:**
- Modify: `lib/features/calendar.dart` — move `_getCategoryColor` from `_MonthGrid` and `_DayDetailPanel` to top-level function

- [ ] **Step 1: Add top-level helper and remove duplicates**

In `lib/features/calendar.dart`, add:
```dart
Color categoryColor(String cat) {
  switch (cat) {
    case 'Work': return Colors.blue;
    case 'Personal': return Colors.green;
    case 'Urgent': return Colors.red;
    default: return Colors.orange;
  }
}
```

Then in `_MonthGrid`, replace `_getCategoryColor(e.category)` with `categoryColor(e.category)` and delete the `_getCategoryColor` method from `_MonthGrid`.

In `_DayDetailPanel`, replace `_getCategoryColor(e.category)` with `categoryColor(e.category)` and delete the `_getCategoryColor` method from `_DayDetailPanel`.

- [ ] **Step 2: Analyze and commit**

Run: `dart analyze lib/`
Expected: No errors.

```bash
git add lib/features/calendar.dart
git commit -m "shrink: extract duplicate _getCategoryColor to top-level helper"
```

---

### Task 8: Simplify habit streak calculation to single pass

**Files:**
- Modify: `lib/features/habits.dart` — combine current streak and max streak into one loop

- [ ] **Step 1: Rewrite getStreaks()**

Replace the entire `getStreaks()` method (lines 184-237) with a single-pass version:

```dart
  Map<String, int> getStreaks(int habitId) {
    final dates = _habitLogsByHabitId[habitId] ?? {};
    if (dates.isEmpty) return {'current': 0, 'max': 0};

    final sorted = dates.map((d) => DateTime.parse(d)).toList()..sort();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final yesterday = today.subtract(const Duration(days: 1));

    int maxStreak = 0;
    int currentStreak = 0;
    int temp = 1;

    for (int i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i].difference(sorted[i - 1]).inDays == 1) {
        temp++;
      } else if (i > 0) {
        if (temp > maxStreak) maxStreak = temp;
        temp = 1;
      }
    }
    if (temp > maxStreak) maxStreak = temp;

    // ponytail: reverse scan for current streak
    final lastLog = sorted.last;
    if (lastLog == today || lastLog == yesterday) {
      currentStreak = 1;
      for (int i = sorted.length - 2; i >= 0; i--) {
        if (sorted[i + 1].difference(sorted[i]).inDays == 1) {
          currentStreak++;
        } else {
          break;
        }
      }
    }

    return {'current': currentStreak, 'max': maxStreak};
  }
```

- [ ] **Step 2: Analyze and commit**

Run: `dart analyze lib/`
Expected: No errors.

```bash
git add lib/features/habits.dart
git commit -m "shrink: combine streak calc into single pass"
```

---

### Task 9: Remove 100ms timer in LifeScreen, fix false precision

**Files:**
- Modify: `lib/features/life.dart` — change timer interval, fix percentage precision

- [ ] **Step 1: Change timer to 1 second and fix percentage precision**

In `lib/features/life.dart`:
1. Change line 76: `Timer.periodic(const Duration(milliseconds: 100), ...)` → `Timer.periodic(const Duration(seconds: 1), ...)`
2. Change line 174: `formattedPercentage = lifePercentage.toStringAsFixed(7)` → `formattedPercentage = lifePercentage.toStringAsFixed(2)`

- [ ] **Step 2: Analyze and commit**

Run: `dart analyze lib/`
Expected: No errors.

```bash
git add lib/features/life.dart
git commit -m "shrink: reduce LifeScreen timer to 1s, fix false precision"
```

---

### Task 10: Drop copyWith boilerplate from models

**Files:**
- Modify: `lib/features/notes.dart` — remove `Note.copyWith()`, inline its only callers
- Modify: `lib/features/habits.dart` — remove `Habit.copyWith()`, inline its only caller

- [ ] **Step 1: Remove Note.copyWith() and inline usages**

In `lib/features/notes.dart`:
1. Delete the entire `copyWith` method from `Note` class (lines 65-82)
2. In `togglePin()` (line 233), replace:
```dart
await save(note.copyWith(pinned: !note.pinned));
```
with:
```dart
await save(Note(
  id: note.id, title: note.title, content: note.content,
  color: note.color, pinned: !note.pinned, tags: note.tags,
  createdAt: note.createdAt, updatedAt: DateTime.now(),
));
```

- [ ] **Step 2: Remove Habit.copyWith() and inline usage**

In `lib/features/habits.dart`:
1. Delete the entire `copyWith` method from `Habit` class (lines 35-42)
2. In `updateReminder()` (line 135), replace:
```dart
final updated = current.copyWith(reminderTime: reminderTime);
```
with:
```dart
final updated = Habit(
  id: current.id, name: current.name, icon: current.icon,
  reminderTime: reminderTime, createdAt: current.createdAt,
);
```

- [ ] **Step 3: Analyze and commit**

Run: `dart analyze lib/`
Expected: No errors.

```bash
git add lib/features/notes.dart lib/features/habits.dart
git commit -m "delete: copyWith boilerplate, inline at call sites"
```
