# Personal App
## Download

| Platform | Link |
|---|---|
| Android APK | [Download latest APK](https://github.com/kssaichandan/PERSONAL-APP/actions/workflows/build-apk.yaml) → select latest run → download **app-debug-apk** |
| Source code | [github.com/kssaichandan/PERSONAL-APP](https://github.com/kssaichandan/PERSONAL-APP) |

## Features

- **Notes** — Rich text editor powered by Flutter Quill with search, tags, and bulk select/delete
- **Habits** — Track daily habits with streaks, completion history, and monthly calendar view
- **Calendar** — Event management with category filtering, search, and monthly navigation
- **Calculator** — Basic and scientific math with memory functions (M+/M-/MR/MC), constants (π, e), and expression history
- **Life** — Life expectancy tracker showing weeks lived/remaining, age, and personalized milestones
- **Settings** — Theme toggle, import/export data, biometric lock, app info

## Tech Stack

- **Framework**: Flutter 3.44+, Dart 3.12+
- **State Management**: Provider
- **Storage**: SQLite via sqflite + sqlcipher (encrypted)
- **Push Notifications**: flutter_local_notifications + workmanager
- **Biometrics**: local_auth

## Build

```bash
flutter pub get
flutter build apk --debug
```

## License

MIT
