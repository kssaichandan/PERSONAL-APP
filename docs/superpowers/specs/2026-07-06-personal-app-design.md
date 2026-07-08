# Personal App — Design Spec

## Tech Stack
- **Framework**: Flutter 3.44.x (Material 3)
- **Language**: Dart 3.12.x
- **Database**: sqflite (SQLite)
- **State Management**: Provider (ChangeNotifier + MVVM)

## Architecture: Feature-First + Provider

Each feature is one self-contained file. Adding a new feature = new file + new table + new nav item.

```
lib/
├── main.dart                    # Entry point + MultiProvider + BottomNav (5 tabs)
├── database.dart                # sqflite helper (6 tables)
└── features/
    ├── notes.dart               # Note model + NotesProvider + screens
    ├── calendar.dart            # CalendarEvent model + CalendarProvider + screens
    ├── calculator.dart          # CalculatorProvider + screen + expression parser
    ├── habits.dart              # Habit model + HabitsProvider + screens
    └── life.dart                # LifeProvider + Life screen
```

## Navigation
- Bottom nav with 5 tabs (Notes, Habits, Calendar, Calculator, Life)
- IndexedStack keeps tab state alive
- Modal bottom sheets for event editing, day details

## Features

### Notes
- Color-coded note cards with pin, search, tag filtering
- Plain text editor via TextField (flutter_quill removed — ponytail cut)
- CRUD with sqflite

### Habits
- Daily habit tracking with weekly checklist + monthly calendar
- Streak tracking (current + max) via single-pass algorithm
- Habit reminders via flutter_local_notifications
- 7 default icons: bathtub, gaming, exercise, book, water, bed, school

### Calendar
- Month grid view with event dots, habit completion indicators, note history
- Create/edit/delete events with date, time, category, notes
- Day detail panel with all 3 data sources (events, habits, notes)

### Calculator
- Standard ops (+, -, ×, ÷) + functions (sin, cos, tan, log, ln, sqrt)
- Constants: π, e; postfix: %
- Memory functions (MC/MR/M+/M-), history (last 50)
- Pure Dart recursive descent parser (~100 lines, zero deps)

### Life Tracker
- Date of birth setup with live-updating time elapsed
- Life progress meter (80-year expectancy baseline)
- Real-time metrics: days, hours, minutes, seconds, milliseconds

## Database
- sqflite with 6 tables: `notes`, `calendar_events`, `calculator_history`, `habits`, `habit_logs`, `settings`
- Schema version 2 (v1 → v2 adds color/tags columns, habits/habit_logs/settings tables)
- Pre-populated default habits on first create (Bathing, Playing, Exercise)
- All CRUD via Provider → sqflite

## State
- `NotesProvider` — loads, filters, saves, deletes notes
- `CalendarProvider` — loads events by month, CRUD + notification scheduling
- `CalculatorProvider` — expression, result, history, memory
- `HabitsProvider` — habit CRUD, daily logs, streaks, reminders
- `LifeProvider` — DOB load/save/reset
- All extend `ChangeNotifier`, provided via `MultiProvider`

## Build & CI
- CI-only builds (no local Flutter SDK) via GitHub Actions
- Build: `flutter build apk --debug` on push/PR to master
- APK downloadable from Actions artifact
- `coreLibraryDesugaringEnabled` for flutter_local_notifications compatibility
