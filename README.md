# quran_memorization

A Flutter-based cross-platform Quran memorization application with tracking, spaced repetition, and progress management.

## Features

- 📱 **Cross-platform** — iOS, Android, Web, Windows, macOS, Linux
- 🧠 **Memorization tracking** — Track progress through the Quran
- 📊 **Progress dashboard** — Visual progress indicators
- 🔄 **Spaced repetition** — Smart review scheduling
- 💾 **Local storage** — Progress saved offline

## Tech Stack

- **Framework:** Flutter (Dart)
- **Platforms:** iOS, Android, Web, Desktop
- **State Management:** [See pubspec.yaml]

## Setup

### Prerequisites
- Flutter SDK 3.x+
- Dart SDK

### Installation
```bash
cd quran_memorization
flutter pub get
flutter run  # For mobile
flutter run -d chrome  # For web
```

### Build for Web
```bash
flutter build web
# Output in build/web/
```

## Project Structure
```
lib/           # Dart source code
android/       # Android platform
ios/           # iOS platform
web/           # Web platform
linux/         # Linux platform
macos/         # macOS platform
windows/       # Windows platform
assets/        # App assets
test/          # Tests
```

## Related Projects

This app complements the **ISLAM ACADEMY** project's hifz planner with a native mobile experience. The ISLAM ACADEMY provides a web-based alternative.

## Status

This project is under active development. Contributions welcome!
