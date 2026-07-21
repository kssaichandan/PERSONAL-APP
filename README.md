# Personal App
## Download

| Platform | Link |
|---|---|
| Android APK | [Download latest APK](https://github.com/kssaichandan/PERSONAL-APP/releases/latest) |
| Source code | [github.com/kssaichandan/PERSONAL-APP](https://github.com/kssaichandan/PERSONAL-APP) |

## Features

- **Notes** — Rich text editor powered by Flutter Quill with search, color coding, priority levels, and bulk actions
- **Habits** — Track habits with 3 modes (Yes/No, Count with Target, Free Count), streaks, weekly/monthly views, and drag-reorder
- **Calendar** — Event management with category filtering, search, recurrence, and monthly navigation
- **Calculator** — Basic and scientific math with memory functions, constants, and expression history
- **Life** — Real-time life tracker showing days lived, remaining time, and life progress
- **Settings** — Theme customization, import/export data, notification controls, and app preferences

## Tech Stack

- **Framework**: Flutter 3.22+, Dart 3.7+
- **State Management**: Provider
- **Storage**: SQLite via sqflite
- **Push Notifications**: flutter_local_notifications + timezone

## Build

```bash
flutter pub get
flutter build apk --debug
```

## License

MIT
