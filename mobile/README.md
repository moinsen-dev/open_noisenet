# NoiseNet Mobile

Flutter mobile application for OpenNoiseNet environmental noise monitoring platform.

## Features

- **Device Management**: Pair and configure ESP32/Raspberry Pi noise sensors
- **Real-time Monitoring**: Live noise level visualization and alerts
- **On-device AI**: Sound classification using minicpm-o-2.6 model
- **Offline Capability**: Store data locally and sync when connected
- **Location-based**: Automatic device location detection and management

## Architecture

- **State Management**: BLoC pattern for predictable state handling
- **Dependency Injection**: GetIt for service location
- **API Layer**: Retrofit for type-safe HTTP communication
- **Database**: SQLite for local data persistence
- **Audio Processing**: Native platform integration for real-time capture

## Getting Started

### Prerequisites

- Flutter 3.13.0+
- Dart 3.1.0+
- Android Studio / Xcode for platform-specific development

### Installation

```bash
# Get dependencies
flutter pub get

# Generate code
flutter packages pub run build_runner build

# Run the app
flutter run
```

### Development Build

```bash
# Run with development flavor
flutter run --flavor development --target lib/main_development.dart
```

### Production Build

```bash
# Build production APK
flutter build apk --flavor production --target lib/main_production.dart

# Build production iOS
flutter build ios --flavor production --target lib/main_production.dart
```

## Configuration

The app connects to the OpenNoiseNet backend API. Configure the base URL in:

- Development: `lib/core/config/development_config.dart`
- Production: `lib/core/config/production_config.dart`

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/
```

## Contributing

Please read the main [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines.