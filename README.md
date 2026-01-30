# flutter_wrapper

Flutter wrapper app for a single web experience.

## Configuration

- Update `lib/app_config.dart` with the correct `baseUrl`.
- Add Firebase configuration files (`google-services.json` for Android and `GoogleService-Info.plist` for iOS).
- Add a splash image at `assets/splash.png` and app icon at `assets/icon.png`.
- Run native asset generation locally:
  - `flutter pub run flutter_native_splash:create`
  - `flutter pub run flutter_launcher_icons:main`
- Configure deep link URL schemes for iOS/Android as needed.

## Features

- WebView wrapper with JavaScript bridge (`FlutterBridge`).
- Disables zoom, horizontal scroll, and overscroll.
- Persists session URL across launches.
- Handles back button navigation.
- Deep link and FCM route handling.
- Offline screen handling.
- HTTPS-only navigation and external link handling.

## Development

Run tests with:

```bash
flutter test
```
