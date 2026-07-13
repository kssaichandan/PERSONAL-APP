# Personal App — Design Spec

## Tech Stack
- **Framework**: Flutter (Material 3)
- **Language**: Dart 3
- **Database**: sqflite (SQLite)
- **State Management**: Provider (ChangeNotifier + MVVM)
- **Rich Text**: flutter_quill

## Architecture: Feature-First + Provider

Each feature is one self-contained file. Adding a new feature = new file + new table + new nav item.

```
lib/
├── main.dart                    # Entry point + MultiProvider + BottomNav
├── database.dart                # sqflite helper (3 tables)
└── features/
    ├── notes.dart               # Note model + NotesProvider + screens
    ├── calendar.dart            # CalendarEvent model + CalendarProvider + screens
    └── calculator.dart          # CalculatorProvider + screen + expression parser
```

## Navigation
- Bottom nav with 3 tabs (supports up to 5; beyond that → drawer)
- IndexedStack keeps tab state alive
- Modal bottom sheets for event editing

## Features

### Notes
- Rich text (bold, italic, lists, images) via flutter_quill
- CRUD with sqflite
- Search, pin to top, swipe to delete

### Calendar
- Month view grid (custom ~50 lines) + day event list
- Create/edit/delete events with title, date, time, notes
- Stored in sqflite events table

### Calculator
- Standard ops (+, -, ×, ÷) + scientific (sin, cos, log, sqrt, π, e)
- Expression history stored in sqflite
- Pure Dart recursive descent parser (~70 lines)

## Database
- sqflite with 3 tables: `notes`, `calendar_events`, `calculator_history`
- Schema version 1

## State
- `NotesProvider` — loads, filters, saves, deletes notes
- `CalendarProvider` — loads events by month, CRUD
- `CalculatorProvider` — expression, result, history
- All extend `ChangeNotifier`, provided via `ChangeNotifierProvider`
