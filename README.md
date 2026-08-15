# 📱 Personal App — Ultimate Personal Productivity Suite

> A handcrafted, high-performance personal productivity suite built with Flutter 3.27 & Material Design 3. Featuring rich text notes, habit streak heatmaps, dynamic category calendar agendas, scientific calculator, life journey analytics, and custom theme engines.

---

## ⚡ Quick Download

Download the latest release directly to your Android device:

<div align="center">

[![Download APK](https://img.shields.io/badge/⚡_Direct_Download-Latest_Android_APK-2EA44F?style=for-the-badge&logo=android&logoColor=white)](https://github.com/kssaichandan/PERSONAL-APP/releases/latest/download/app-release.apk)
[![All Releases](https://img.shields.io/badge/📦_GitHub-Releases_Page-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/kssaichandan/PERSONAL-APP/releases)

**[📥 Click Here to Download Latest APK (`app-release.apk`)](https://github.com/kssaichandan/PERSONAL-APP/releases/latest/download/app-release.apk)**  
*(Also view all changelogs & versions on the **[GitHub Releases Page](https://github.com/kssaichandan/PERSONAL-APP/releases)**)*

*(Compatible with Android 8.0+ / API level 26+)*

</div>

---

## ✨ Highlights & Features

### 📝 Notes Engine
- **Rich Text Editing**: Full formatting powered by Flutter Quill (headers, lists, bold, italics, code blocks).
- **Glassmorphic Search**: Floating pill search bar with real-time query filtering.
- **Universal Priority Badges**: Priority tagging (**High** 🔴 Crimson Fire, **Medium** 🟠 Amber Bolt, **Low** 🔵 Cyan Arrow) rendered in both Grid and List modes.
- **Dual-Direction Gestures**: Swipe Right to Pin/Unpin notes, Swipe Left to move notes to Trash with tactile haptics.
- **Trash Management**: Drag-handle bottom sheet with empty trash confirmation guards.

### 🔥 Habit Tracker & Heatmaps
- **Dynamic Gauge Card**: Animated `TweenAnimationBuilder` gauge counter with dynamic motivational micro-copy.
- **Multi-Tier Flame Badges**: Spark (1-2 days), Blaze (3-6 days), Inferno (7-29 days), and Cosmic Fire (30+ days) streak badges.
- **7-Column Heatmap Calendar**: Continuous squircle grid with 4-stage log intensity fills and tap-to-log interactivity.
- **Drag & Reorder**: Continuous 1.06x scale transform feedback during habit list reordering.

### 📅 Calendar & Agenda Timeline
- **Multi-View System**: Seamless animated transitions between **Month**, **Week**, **Day**, and **Agenda** views.
- **Category Indicators**: Color-coded event category dots (**Work** 🔵, **Personal** 🟢, **Urgent** 🔴).
- **Timeline Connectors**: Continuous timeline connector agenda list with duration badges and node markers.
- **Recurrence Picker**: Recurrence options (**Daily**, **Weekly**, **Monthly**) with optional "Until Date" picker.

### 𝄠 Scientific Calculator
- **Dynamic Typography**: Auto-scaling expression & result display with comma-formatted numbers (`1,000,000`).
- **Accent Equals Key**: Primary dynamic seed color key fill for instantaneous equals action.
- **Scientific Drawer**: Smooth sliding panel for trigonometric, logarithmic, root, and constant (`π`, `e`) operations.
- **Expression History**: Slide-up history sheet with touch-to-reuse previous calculations.

### ⏳ Life Journey Analytics
- **LIVE Radar Pulse**: Dual-concentric pulse wave badge indicating real-time life tracking.
- **Time Unit Cards**: Responsive year, month, and day metric cards with soft glassmorphic borders.
- **Progress Meter**: Dynamic smooth color interpolation (`Color.lerp`) from primary to tertiary to warning colors.

### 🎨 Custom Theme System
- **Dynamic Seed Color Picker**: Interactive 2D gradient color picker with live hexadecimal input.
- **Theme Preview Cards**: Interactive phone screen previews for Light, Dark, and System modes.
- **Granular Controls**: Dynamic notification permissions, backup import/export, and data wipes.

---

## 🛠️ Technology Stack

- **Framework**: Flutter 3.27+ / Dart 3.7+
- **Design System**: Material Design 3 (M3) Dynamic Color Schemes (`ColorScheme.fromSeed`)
- **State Management**: `provider` 6.1.5
- **Database Storage**: SQLite via `sqflite` 2.4.0
- **Rich Text Editor**: `flutter_quill` 11.0.0
- **Notifications**: `flutter_local_notifications` 18.0.0 + `timezone`

---

## ⚙️ Development & Build

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run static code analyzer
flutter analyze

# 3. Execute unit and widget test suite (66/66 tests)
flutter test

# 4. Build release APK for Android
flutter build apk --release
```

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for details.
