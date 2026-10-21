# meshresq

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Live area alerts

When the app is open, it connects to the backend WebSocket at `/ws/live` and displays incoming `BROADCAST_ALERT` events in an in-app alert banner. It also asks for notification permission and subscribes to the Firebase topic `meshreq_area_alerts`. Firebase can display notification messages while the app is backgrounded, provided the backend's Firebase Admin service account and the mobile Firebase platform configuration are set up. The live socket retries after interruptions and pauses in the background. Force-stopped apps and devices without network access cannot receive pushes until they are opened or reconnected.
