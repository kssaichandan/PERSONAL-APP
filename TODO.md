# Personal App — Comprehensive Issue Tracker & Todo List

Generated from full codebase audit (2026-07-10). All issues categorized by severity with actionable checkboxes.

---

## 🔴 CRITICAL — Must Fix First (Blocking/Production Risk)

### C1: Zero Tests — No Regression Safety
- [x] Create `test/` directory structure
- [x] Write unit tests for all Providers (`NotesProvider`, `HabitsProvider`, `CalendarProvider`, `CalculatorProvider`, `LifeProvider`)
- [x] Write widget tests for each screen (`NotesScreen`, `HabitsScreen`, `CalendarScreen`, `CalculatorScreen`, `LifeScreen`)
- [ ] Add integration test for critical flows (create note → edit → delete, add habit → toggle → streak, create event → notify)
- [ ] Add `flutter test` step to CI workflow

### C2: No Native Config — Can't Build Locally
- [ ] Run `flutter create .` locally to generate `android/` and `ios/` directories
- [ ] Commit generated native folders to git
- [ ] Configure Android `minSdkVersion`, `targetSdkVersion`, `compileSdkVersion` in `android/app/build.gradle.kts`
- [ ] Configure iOS deployment target in `ios/Runner.xcodeproj` / `Podfile`
- [ ] Add app icons, launch screens, splash screen config
- [ ] Verify local debug build works: `flutter run`

### C3: Silent Error Swallowing in Production
- [x] `habits.dart:88` — `toggleLog` catch block: show SnackBar on failure
- [x] `calculator.dart:30,40,50` — `clearHistory`, `deleteHistoryEntry`, `_saveToHistory`: show SnackBar
- [x] `life.dart:23,41,49` — `loadDOB`, `saveDOB`, `resetDOB`: show SnackBar
- [x] `notes.dart` — `save`, `delete`, `load`: show SnackBar
- [x] `calendar.dart` — `save`, `delete`, `load`: show SnackBar
- [x] Replace all `catch (_) {}` with `catch (e) { debugPrint(...); if (mounted) showSnackBar(...); }`
- [x] Keep `kDebugMode` guard for `debugPrint` but always show user feedback

### C4: Global Mutable `notifications` Variable
- [x] Create `NotificationService` class wrapping `FlutterLocalNotificationsPlugin`
- [x] Register as `Provider` in `main.dart` (singleton via `Provider.value` or `ChangeNotifierProvider`)
- [x] Inject into `CalendarProvider`, `HabitsProvider` via constructor
- [x] Remove global `final notifications = ...` from `main.dart`, `calendar.dart`, `habits.dart`
- [x] Update all call sites to use injected service

### C5: Missing Runtime Notification Permission (Android 13+)
- [x] Add `permission_handler` dependency
- [x] On app start (`main.dart`), request `Permission.notification` if not granted
- [ ] Show rationale dialog before requesting
- [ ] Handle permanent denial (open app settings)
- [ ] Test on Android 13+ emulator/device

---

## 🟠 HIGH — Missing Core UX Features (Common Sense)

### H1: No Delete Button on Note Cards
- [x] Add trailing `IconButton(Icons.delete_outline)` to note card in `notes.dart:_buildGrid`
- [x] Show confirmation dialog before delete
- [x] Call `provider.delete(note.id)` on confirm
- [x] Add haptic feedback

### H2: No Edit Habit Name/Icon
- [x] Add edit button to habit detail header (`habits.dart:377`)
- [x] Create `_showEditHabitDialog` pre-filled with current name/icon/reminder
- [x] Add `updateHabit` method to `HabitsProvider` (name, icon, reminder)
- [x] Call provider method on save

### H3: No Settings Screen
- [x] Create `SettingsScreen` widget (new file `lib/features/settings.dart`)
- [x] Add to bottom nav (6th tab)
- [x] Implement sections:
  - [x] **Appearance**: Theme toggle (Light/Dark/System), color seed picker
  - [x] **Notifications**: Global toggle, per-feature toggles (habits, calendar)
  - [x] **Data**: Export all (JSON), Import (JSON), Clear all data (with confirmation)
  - [x] **Life Tracker**: Life expectancy input (default 80), date format
  - [x] **Calculator**: Scientific mode toggle, decimal places
  - [x] **About**: Version, license, GitHub link
- [ ] Persist settings in `settings` table (key-value)

### H4: No Data Export/Import/Backup
- [x] Add export functionality in settings (JSON with share_plus)
- [x] Include all 6 tables: notes, calendar_events, calculator_history, habits, habit_logs, settings
- [x] Add import functionality in settings (JSON with file_picker)
- [x] Transaction-based import with validation
- [x] Reload all providers after import

### H5: No Recurring Events in Calendar
- [x] Add `recurrence` field to `calendar_events` table: `'none' | 'daily' | 'weekly' | 'monthly' | 'yearly'`
- [x] Add `recurrence_end` date field (nullable)
- [x] Update `CalendarEvent` model and `toMap/fromMap`
- [x] Add recurrence selector in `EventEditor` (dropdown)
- [x] Modify `eventsForDay` to expand recurring events
- [ ] Handle notification scheduling for recurring events

### H6: No Event Search/Filter in Calendar
- [x] Add search bar in CalendarScreen AppBar
- [x] Filter events by title/notes/category in CalendarProvider
- [x] Add category filter via PopupMenuButton (General, Work, Personal, Urgent)

### H7: No Copy to Clipboard in Calculator
- [x] Add `IconButton(Icons.content_copy)` next to result display (in AppBar)
- [x] Copy expression on long-press expression, result on long-press result (already existed)
- [x] Show "Copied!" SnackBar
- [x] Added `flutter/services.dart` for `Clipboard.setData`

### H8: Scientific Mode Hidden (Functions Exist but No UI)
- [x] Add `scientificMode` setting (persisted in settings table)
- [x] Add toggle in Calculator AppBar (functions icon)
- [x] Show extra button row: `sin`, `cos`, `tan`, `log`, `ln`, `sqrt`, `π`, `e`, `^`, `(`, `)`
- [x] Use responsive grid: 4 cols standard, 6 cols scientific

### H9: Life Expectancy Hardcoded (80 Years)
- [x] Add `life_expectancy` to `settings` table (default 80)
- [x] Add number input in Settings → Life Tracker section
- [x] Update `LifeProvider` to read from settings
- [x] Recalculate progress meter on change

### H10: No Habit Reordering
- [x] Add `display_order` column to `habits` table
- [x] Update `Habit` model with `displayOrder` field
- [x] Add `reorderHabits` method to `HabitsProvider`
- [x] Update `saveHabit` to assign display_order
- [x] Update `load` to order by display_order
- [x] Add `ReorderableListView` with drag handle in `HabitsScreen`

### H11: No Bulk Select/Delete
- [x] **Notes**: Long-press to enter selection mode, checkboxes, Select All/Clear/Delete toolbar
- [x] **Habits**: Long-press to enter selection mode, checkboxes, Select All/Clear/Delete toolbar
- [x] **Calendar**: Multi-select in day detail panel (to be added)
- [x] Add `deleteMultiple(ids)` to each Provider

### H12: No Onboarding/Tutorial
- [x] Add `onboarding_complete` flag to SharedPreferences
- [x] Show onboarding flow on first launch (6 pages: Notes, Habits, Calendar, Calculator, Life, Settings)
- [x] Use `shared_preferences` for persistence
- [x] Add "Show Tutorial" button in Settings to replay

---

## 🟡 MEDIUM — Layout, Responsive & Overflow Issues

### M1: Notes Grid Fixed 2 Columns
- [x] Replace `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2)` with responsive logic
- [x] Use `LayoutBuilder` to calculate crossAxisCount: <400dp=1, 400-800=2, 800-1200=3, >1200=4
- [x] Or add `flutter_screenutil` / `responsive_framework` for breakpoint system

### M2: Calendar Grid Fixed 7 Columns (Too Narrow)
- [x] Use `LayoutBuilder` in `_MonthGrid` to calculate cell width
- [x] Minimum cell width ~40dp, adjust crossAxisCount dynamically
- [x] On very small screens: consider horizontal scroll or compact view

### M3: Habits Horizontal List Overflows
- [x] Wrap `ListView.builder` in `SingleChildScrollView(scrollDirection: Axis.horizontal)`
- [x] Or use `Wrap` with `direction: Axis.horizontal` for auto-wrap
- [x] Add "Show All" button that opens full-screen habit grid

### M4: Life Metrics GridView Fixed 2 Cols, Overflow Risk
- [x] Use `ResponsiveGridView` or `LayoutBuilder` for crossAxisCount
- [x] Format large numbers with compact notation (1.2M, 500K) using `NumberFormat.compact()`
- [x] Ensure card height adapts to content

### M5: Calculator Expression/Result Overflow
- [x] Current `SingleChildScrollView(reverse: true)` works but test with 50+ chars
- [x] Add `maxLines: 1` with `overflow: TextOverflow.ellipsis` + tooltip on long-press
- [x] Consider marquee animation for very long expressions

### M6: No Responsive Framework (Intentional but Causing Issues)
- [x] Decide: `responsive_framework` (breakpoints) vs `flutter_screenutil` (design scaling)
- [x] Add chosen package to `pubspec.yaml`
- [x] Wrap `MaterialApp` with responsive builder
- [x] Define breakpoints: phone (<600), tablet (600-1200), desktop (>1200)

### M7: Portrait/Landscape Not Tested
- [ ] Test all screens in landscape mode
- [ ] Add `MediaQuery` checks for orientation-specific layouts where needed
- [ ] Ensure bottom nav doesn't overlap content in landscape

### M8: Long Text No Tooltip in Notes Grid
- [x] Add `Tooltip(message: note.title)` wrapping title `Text`
- [x] Add `Tooltip(message: note.content)` wrapping content `Text`
- [x] Show full text on long-press or hover

---

## 🔵 LOW — Code Quality & Technical Debt

### L1: `plainText()` Circular Dependency Risk
- [x] Move `plainText()` to new shared file `lib/utils/text_utils.dart`
- [x] Import in both `notes.dart` and `calendar.dart`
- [x] Remove from `calendar.dart:447`

### L2: Database Migration Strategy Missing
- [x] Document migration plan in `database.dart` comments
- [x] Add `onUpgrade` handlers for v2→v3, v3→v4 with version checks
- [x] Use `ALTER TABLE` for additive changes, recreate for breaking changes
- [x] Test migration by installing v1, upgrading to v2

### L3: LifeScreen Rebuilds Every Second (Timer)
- [x] Replace `Timer.periodic` with `Stream.periodic(Duration(seconds: 1))`
- [x] Use `StreamBuilder` in `LifeScreen` to rebuild only metrics
- [x] Extract metrics into separate widget to minimize rebuild scope

### L4: CalendarProvider Reloads All Events on Month Nav
- [x] Cache events by month in `_eventsCache: Map<String, List<CalendarEvent>>`
- [x] Only fetch from DB if month not in cache
- [x] Invalidate cache on save/delete

### L6: Calculator `%` Only Post-Number
- [ ] Update parser `_factor()` to handle `%` after `)` or function calls
- [x] Treat `%` as postfix operator with precedence like `^`
- [x] Test: `(1+2)%`, `sin(30)%`, `50%` all work

### L7: Calendar Notifications Not Rescheduled on Boot
- [x] Add `workmanager` dependency
- [x] Register background task to reschedule all pending notifications
- [x] Trigger on `BOOT_COMPLETED` (Android) / background fetch (iOS)
- [x] Call `CalendarProvider.load()` and re-schedule in background

### L8: Minimal Analysis Options
- [x] Update `analysis_options.yaml` with strict rules:
  ```yaml
  include: package:flutter_lints/flutter.yaml
  linter:
    rules:
      prefer_const_constructors: true
      prefer_const_declarations: true
      avoid_print: true
      prefer_final_locals: true
      prefer_final_fields: true
      avoid_unused_constructor_parameters: true
      no_leading_underscores_for_local_identifiers: true
      always_specify_types: true
      avoid_returning_null_for_void: true
      avoid_relative_lib_imports: true
      avoid_slow_async_io: true
      cancel_subscriptions: true
      close_sinks: true
      control_flow_in_finally: true
      unawaited_futures: true
  ```

---

## ♿ Accessibility (A11y)

### A1: Missing Tooltips on Some IconButtons
- [x] Audit all `IconButton` usages across all files
- [x] Add `tooltip` to every `IconButton` without one
- [x] Use descriptive text: "Delete note", "Edit event", "Add habit", etc.

### A2: Life Screen Real-Time Metrics Not Screen-Reader Friendly
- [x] Wrap metric values in `Semantics(label: "Total days alive: 12,345")`
- [x] Add `Semantics` wrapper to `_MetricCard`

### A3: Custom Widgets Lack Semantic Labels
- [x] `_MetricCard` (`life.dart`): Add `Semantics` wrapper with label
- [x] `_CalcButton` (`calculator.dart`): Add `Semantics` with `semanticLabel`
- [x] `_MemoryButton`: Add `Semantics` wrapper with label

### A4: Color-Only Indicators
- [x] Habit streak fire icon: add text "🔥 7 day streak" or `Semantics`
- [x] Calendar event dots: add `Tooltip` or `Semantics` with event count
- [x] Ensure 4.5:1 contrast for all text (already fixed per notes.md)

---

## 🔐 Security & Privacy

### S1: No Database Encryption
- [ ] Evaluate: Add `sqflite_sqlcipher` for encrypted DB
- [x] Or use `flutter_secure_storage` for sensitive fields only (DOB, maybe)
- [x] Document decision in `SECURITY.md`

### S2: No Local Auth for Sensitive Data
- [x] Add `local_auth` dependency
- [x] Require biometric/PIN to open Life screen (optional, in Settings)
- [ ] Use secure storage for any tokens/secrets

### S3: Notification Permission Not Requested at Runtime
- [x] Covered in C5

### S4: No Data Export = User Lock-in
- [x] Covered in H4

---

## 📦 CI/CD & Infrastructure

### CI1: No Test Execution in CI
- [x] Add `flutter test --coverage` step in `build-apk.yaml`
- [x] Upload coverage report as artifact

### CI2: No Code Coverage Enforcement
- [ ] Add `very_good_analysis` or `coverage` badge
- [ ] Set minimum coverage threshold (e.g., 80%)

### CI3: Only Debug APK Built
- [x] Add `flutter build apk --release` and `flutter build appbundle` steps
- [x] Upload both as separate artifacts
- [ ] Sign release builds (configure keystore in GitHub Secrets)

### CI4: Lint Rules Not Strict Enough
- [x] Covered in L8

### CI5: No Dependency Vulnerability Scanning
- [x] Add `dart pub outdated` check in CI
- [x] Add `OSV-Scanner` step for vulnerability scan

---

## 📋 Phase-Based Execution Order

### Phase 1: Foundation (Week 1-2) — DO FIRST
- [ ] C1: Write tests (start with Provider unit tests)
- [ ] C2: Generate & commit native config (`flutter create .`)
- [ ] C3: Fix all silent catches with user feedback
- [ ] C4: Eliminate global notifications variable
- [ ] C5: Add runtime notification permission

### Phase 2: Core UX (Week 2-3)
- [ ] H1: Delete button on note cards
- [ ] H2: Edit habit name/icon
- [ ] H3: Settings screen (start with theme + life expectancy)
- [ ] H4: Data export/import (JSON)
- [ ] H7: Copy to clipboard in calculator
- [ ] H8: Scientific mode toggle
- [ ] H9: Configurable life expectancy

### Phase 3: Layout & Responsive (Week 3-4)
- [ ] M6: Add responsive framework (decide & integrate)
- [ ] M1: Responsive notes grid
- [ ] M2: Responsive calendar grid
- [ ] M3: Fix habits horizontal overflow
- [ ] M4: Responsive life metrics
- [ ] M7: Test portrait/landscape
- [ ] M8: Tooltips for long text

### Phase 4: Advanced Features (Week 4-5)
- [ ] H5: Recurring events
- [ ] H6: Calendar search/filter
- [ ] H10: Habit reordering
- [ ] H11: Bulk select/delete
- [ ] H12: Onboarding flow
- [ ] L7: Background notification reschedule

### Phase 5: Code Quality & Polish (Week 5-6)
- [x] L1: Fix circular dependency
- [x] L2: Document migration strategy
- [x] L3: Optimize LifeScreen timer
- [x] L4: Cache calendar events
- [x] L5: Add dependency injection
- [x] L6: Fix calculator `%` operator
- [x] L8: Harden analysis options
- [x] A1-A4: Accessibility fixes
- [x] S1-S4: Security decisions & implementation

### Phase 6: CI/CD & Release (Week 6)
- [x] CI1-CI5: Complete CI pipeline
- [x] Build & test release AAB/APK
- [ ] Configure code signing
- [ ] Create GitHub Release workflow

---

## 🎯 Quick Wins (Can Do Anytime, <30 min each)

- [x] Add `tooltip` to all remaining `IconButton`s
- [x] Add `hapticFeedback` on button taps
- [x] Format large numbers with compact notation in Life screen
- [x] Add "Copied!" SnackBar helper function
- [x] Extract color constants to theme extension
- [x] Add `// TODO:` comments linking to this file for each issue

---

## 📝 Notes & Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-10 | Created this tracker | Comprehensive audit complete |
| | | |

---

**Total Items: ~85 actionable checkboxes**

Start with **Phase 1** — these are blocking issues. Check off items as completed. Update this file with decisions, blockers, and new findings as you go.