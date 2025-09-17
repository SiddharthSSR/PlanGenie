# PlanGenie Flutter App

This directory contains the Flutter boilerplate for the PlanGenie mobile app. It is intentionally lean so you can iterate quickly during the hackathon and expand it as the product hardens.

## Getting Started
1. Ensure you have Flutter 3.16+ installed and configured (`flutter doctor`).
2. From this folder, fetch packages:
   ```bash
   flutter pub get
   ```
3. Run the app on an emulator or device:
   ```bash
   flutter run
   ```

## Project Layout
- `lib/src/app.dart` – Top-level widget that wires up theming and navigation.
- `lib/src/features/home/home_screen.dart` – Placeholder screen for itinerary planning.
- `lib/src/widgets/async_value_widget.dart` – Helper for rendering async state.
- `test/widget_test.dart` – Example widget test to keep the harness wired up.
- `assets/` – Place images, fonts, and other bundled resources here.

## Next Steps
- Draft real features inside `lib/src/features/` grouped by domain.
- Add Riverpod or another state management package as needs evolve.
- Use `flutter create .` if you need additional platform scaffolding (macOS, web, etc.).
