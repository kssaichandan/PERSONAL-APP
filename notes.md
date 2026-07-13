# Personal App — Dev Notes

## Overview

Personal Flutter app with 5 features: Notes, Habits, Calendar, Calculator, Life Tracker.

Stack: Flutter 3.44.x, Dart 3.12.x, sqflite, Provider, Material 3.

---

## What We've Built

### Notes (`lib/features/notes.dart`)
- Note cards with color, pin, search, tag filtering
- Full note editor with color picker, title, tags, content
- Search across title and content
- Save as SQLite rows via sqflite

### Habits (`lib/features/habits.dart`)
- Track daily habits with weekly checklist and monthly calendar
- Streak tracking (current + max)
- Habit reminders via `flutter_local_notifications`
- 7 default habit icons: bathtub, gaming, exercise, book, water, bed, school

### Calendar (`lib/features/calendar.dart`)
- Month grid view with day dots for events
- Habit completion indicators and note history per day
- Create/edit/delete events with date, time, category, notes
- Event notifications via `flutter_local_notifications`

### Calculator (`lib/features/calculator.dart`)
- Custom recursive descent parser (~100 lines, zero deps)
- Functions: sin, cos, tan, log, ln, sqrt
- Constants: π, e
- `%` postfix, parentheses, exponentiation (`^`)
- Memory functions (MC/MR/M+/M-)
- History: last 50 entries stored in SQLite, per-entry delete + clear-all

### Life Tracker (`lib/features/life.dart`)
- Date of birth setup with live-updating time elapsed
- Life progress meter (80-year expectancy baseline)
- Real-time metrics: days, hours, minutes, seconds, milliseconds
- Timer ticker updating every second

### Database (`lib/database.dart`)
- Singleton `AppDatabase` with lazy init
- 6 tables: `notes`, `calendar_events`, `calculator_history`, `habits`, `habit_logs`, `settings`
- All CRUD via Provider -> sqflite
- Pre-populated default habits on first create

### Main (`lib/main.dart`)
- `MultiProvider` wrapping `MaterialApp`
- Dark/light theme via `ThemeMode.system`, Material 3, deepPurple seed
- Bottom `NavigationBar` with `IndexedStack` (preserves tab state)
- Spacing/radius token arrays and `textTheme` defined for consistency

### CI/CD (`.github/workflows/build-apk.yaml`)
- Trigger: push/PR to master
- `subosito/flutter-action` with `channel: stable`
- Steps: `pub get` → `flutter analyze` → `flutter create .` (generates android/) → `flutter build apk --debug`
- Artifact uploaded as `app-debug-apk`
- No Flutter SDK locally — all builds via GitHub Actions

---

## Bug / Fix History

| # | Issue | Root Cause | Fix |
|---|---|---|---|
| 1 | `flutter analyze` failed: `missing_required_argument` | `QuillController()` constructor requires `selection` param | Added `selection: const TextSelection.collapsed(offset: 0)` |
| 2 | CI fail: `test/widget_test.dart` references `MyApp` | `flutter create .` generates test file with wrong class name | Moved `flutter create .` AFTER `flutter analyze` in CI |
| 3 | CI fail: `FormatException` not const | Lint requires const for exception objects | Added `const` to all `FormatException` throws |
| 4 | CI fail: `use_build_context_synchronously` | `context` in PopupMenuButton onSelected is overlay context, not State context | Changed `if (mounted)` to `if (context.mounted)` |
| 5 | Bottom overflow by 2.0px | Calculator button grid too tall on small screens | Reduced button `vertical` padding `14→10` |
| 6 | `FlutterQuillLocalizations` not found | Missing localization delegates in MaterialApp | Added `FlutterQuillLocalizations.delegates` |
| 7 | No calendar reminders | No notification system | Added `flutter_local_notifications` — schedules on save, cancels on delete |
| 8 | Calculator history: no delete, fully visible | No clear/delete UI | Added clear-all AppBar button + per-entry X button, switched to compact vertical list |
| 9 | GitHub Actions workflow failed | `flutter-version-file: pubspec.yaml` couldn't find Flutter version | Changed to `channel: stable` |
| 10 | CI: `flutter_quill/l10n.dart` doesn't exist | Wrong import path | Changed to `package:flutter_quill/flutter_quill.dart`, use `.delegate` (singular) |
| 11 | CI: `schedule()` undefined in flutter_local_notifications v18 | `schedule()` removed in v18 | Switched to `zonedSchedule()` + `timezone ^0.10.1` package |
| 12 | CI: `NotificationDetails/AndroidNotificationDetails` not found | Missing imports in `calendar.dart` | Added `import 'package:flutter_local_notifications/...'` |
| 13 | CI: `androidScheduleMode` required, `androidAllowWhileIdle` undefined | v18 API change | Replaced `androidAllowWhileIdle: true` with `androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle` |
| 14 | CI: `const_initialized_with_non_constant_value` / `prefer_const_constructors` | Wrong `const` placement | Proper `const` on `AndroidInitializationSettings` and `InitializationSettings` |
| 15 | CI: `calc` undefined in AppBar | `calc` used outside Consumer scope | Wrapped entire Scaffold in `Consumer<CalculatorProvider>` |
| 16 | CI: Non-const `InitializationSettings` / unused import | Missing `const`, leftover import | Made both const, removed unused `timezone/timezone.dart` import from main.dart |
| 17 | CI build: `flutter_local_notifications` needs core library desugaring | Android API level requires desugaring | Added CI step to enable `coreLibraryDesugaringEnabled` + `desugar_jdk_libs` in `android/app/build.gradle` |
| 18 | CI: timezone version doesn't match | `^1.4.0` doesn't exist | Fixed to `^0.10.1` |
| 19 | CI: `sed` can't find `android/app/build.gradle` | Flutter 3.44.x generates Kotlin DSL (`.gradle.kts`) not Groovy (`.gradle`) | Check for `.gradle.kts` first, fallback to `.gradle` |
| 20 | CI: `coreLibraryDesugaringEnabled = true` unresolved in Kotlin DSL | Java boolean getter uses `is` prefix → `isCoreLibraryDesugaringEnabled` | Use `isCoreLibraryDesugaringEnabled = true` in `.gradle.kts` |

---

## Architecture Decisions

### Why sqflite + Provider instead of Drift?
Ponytail: Drift needs `build_runner`, codegen, ~3x deps. For 3 simple tables with CRUD, sqflite + Provider is fewer files, no codegen, ships immediately.

### Why custom parser instead of `math_expressions`?
Ponytail: ~70 lines of recursive descent vs a dependency. Zero deps, zero version risk, easy to extend.

### Why single-file features instead of model/provider/screen folders?
Ponytail: each feature file is <300 lines. Splitting into folders would be 9+ files with no benefit at this scale.

### Why `channel: stable` instead of pinned version?
Simpler for a personal debug APK. No `.flutter-version` file needed. CI always gets latest stable.

### Why theme tokens + textTheme instead of a design system package?
Ponytail: `_spacing` / `_radius` arrays + `ThemeData.textTheme` replace 17 scattered `Colors.grey` references and ~18 hardcoded `fontSize` values with zero new dependencies. A design system package would add a dep for what 4 lines of arrays achieve.

### Why skip shadcn_flutter, responsive_framework, flutter_animate?
Ponytail: Mobile-only app (no tablet/desktop targets). Material 3 Card/ListTile already match what shadcn provides. Micro-interactions are P3 polish — defer until feature stability warrants it.

---

## How to Build (CI only)

Flutter SDK not installed locally. All builds via GitHub Actions CI.

APK at `build/app/outputs/flutter-apk/app-debug.apk` (in the uploaded artifact).

---

## GitHub

- Repo: `https://github.com/kssaichandan/PERSONAL-APP`
- Branch: `master`
- Actions: `https://github.com/kssaichandan/PERSONAL-APP/actions/workflows/build-apk.yaml`
- Download badge: `https://img.shields.io/badge/Download%20APK-Latest-brightgreen?logo=android`

---

## What Was Fixed (2026-07-08) — UI/UX Audit + Redesign

| # | Issue | Fix | File |
|---|-------|-----|------|
| 1 | 17 instances of `Colors.grey` used instead of theme colors — contrast violations | Replaced all with `theme.colorScheme.onSurfaceVariant` / `outlineVariant` / `surfaceContainerHighest` | All feature files |
| 2 | Zero `tooltip` on 12 IconButtons — no accessibility labels | Added `tooltip` to every IconButton | All feature files |
| 3 | 7 distinct border radius values (8/12/16/20/24/28/32) | Unified to 3 (16/24/default) via cardTheme | All feature files |
| 4 | ~18 hardcoded `fontSize` values instead of `textTheme` | Replaced with `theme.textTheme.*` references | All feature files |
| 5 | `Colors.red` for error text (contrast risk) | Changed to `theme.colorScheme.error` | notes.dart, habits.dart |
| 6 | Life tracker used `fontFamily: 'monospace'` on metric values | Removed — system font for accessibility | life.dart |
| 7 | No spacing/radius token scale defined | Added `_spacing` and `_radius` arrays in main.dart | main.dart |
| 8 | Theme had no textTheme definition | Added full textTheme scale to ThemeData | main.dart |
| 9 | Calendar day detail used `Colors.grey.shade300` for drag handle | Changed to `onSurfaceVariant` with alpha | calendar.dart |
| 10 | Habits icon picker used `Colors.grey.shade400/600` for borders/icon | Changed to `theme.colorScheme.outline/onSurfaceVariant` | habits.dart |
| 11 | `plainText()` defined in calendar.dart was referenced from notes.dart | Moved `plainText()` to calendar.dart (only caller) | calendar.dart |

## What Was Fixed (2026-07-07)

| # | Issue | Fix | File |
|---|-------|-----|------|
| 1 | Duplicated `_plainText()` in NotesProvider and NotesScreen | Extracted to top-level `plainText()` | `lib/features/notes.dart` |
| 2 | `path` dependency used only for `join()` | Replaced with string interpolation, removed `path: ^1.9.0` | `lib/database.dart`, `pubspec.yaml` |
| 3 | Silent `catch (_) {}` in calculator history methods | Added `debugPrint` to all 3 catch blocks | `lib/features/calculator.dart` |
| 4 | `unawaited` zonedSchedule without error handling | Added `.catchError()` with debugPrint | `lib/features/calendar.dart` |
| 5 | Calendar `load()` re-scheduled all events on every month nav | Removed scheduling loop from `load()` (save/delete already handle it) | `lib/features/calendar.dart` |
| 6 | Calculator error state not cleared on new input | Reset `_expression`/`_result` on typing after `Error` | `lib/features/calculator.dart` |
| 7 | EventEditor missing `mounted` check before async save | Added `if (!mounted) return;` before save | `lib/features/calendar.dart` |

## What Was Fixed (2026-07-08) — Pre-Release Validation

| # | Issue | Fix | File |
|---|-------|-----|------|
| 1 | 12 `debugPrint()` calls in catch blocks — would block pre-push validation | Wrapped all in `if (kDebugMode)` guards | life.dart, habits.dart, calendar.dart, calculator.dart |

## Remaining Ponytail Debt

- `// ponytail: recursive descent parser, no external dep` — calculator parser has known limitation: `%` only works after number literals, not expressions like `(1+2)%`
- Calendar notifications: initial scheduling for existing events on app restart not implemented (events created after install still get notifications)
- Micro-interactions (flutter_animate) deferred — P3 polish, add when feature set stabilizes
- No responsive framework / shadcn_flutter — not warranted for mobile-only app
- `problems.md` analysis found 0 CRITICAL, 0 HIGH issues — codebase is clean
- No Flutter SDK in dev environment — all CI verification deferred to GitHub Actions
