# IoT Manager — Flutter Application

A cross-platform Flutter application (iOS / Android) that provides a **unified interface** for controlling heterogeneous IoT devices (TP-Link Kasa, GE Cync, Leviton) while abstracting the underlying protocols (local TCP/UDP, proprietary Cloud APIs, and Matter).

---

## Architecture Overview

The project follows **Clean Architecture** principles and is organised into four top-level layers:

```
lib/
├── core/                         # Domain-agnostic building blocks
│   ├── base/
│   │   └── base_device_driver.dart   # Abstract driver interface
│   ├── drivers/
│   │   └── driver_manager.dart       # Routes commands to correct driver
│   ├── models/
│   │   ├── device_model.dart         # Immutable device value object
│   │   └── driver_config.dart        # JSON config schema types
│   ├── services/
│   │   └── firebase_device_registry_service.dart  # Firestore sync
│   └── utils/
│       └── logger.dart
│
├── drivers/                      # Plug-and-Play Driver Framework
│   ├── kasa/         KasaDriver   — local TCP + XOR cipher
│   ├── cync/         CyncDriver   — GE Cync Cloud REST + OAuth2
│   ├── leviton/      LevitonDriver — Leviton Cloud REST + OAuth2
│   ├── matter/       MatterDriver  — platform channel to esp_matter / OS Matter SDK
│   └── discovery/    DiscoveryDriver — mDNS/Zeroconf via bonsoir
│
├── features/                     # Feature slices (vertical slices)
│   ├── auth/
│   │   ├── data/    AuthRepository   — Firebase Auth + Google Sign-In
│   │   └── presentation/
│   │       ├── providers/   authStateProvider, authRepositoryProvider
│   │       └── screens/     LoginScreen
│   ├── devices/
│   │   ├── data/    DeviceRepository
│   │   └── presentation/
│   │       ├── providers/   devicesStreamProvider, deviceStateProvider
│   │       ├── screens/     DeviceListScreen, DeviceDetailScreen, AddDeviceScreen
│   │       └── widgets/     DeviceCard, DeviceControlWidget
│   └── developer_mode/
│       └── presentation/
│           └── screens/     DeveloperModeScreen, DriverConfigScreen
│
├── firebase_options.dart         # ⚠ Replace placeholders with real Firebase config
└── main.dart
```

---

## The Driver Framework

### `BaseDeviceDriver` (abstract)

Every brand driver must extend this class and implement:

| Method | Description |
|---|---|
| `initialize(device, config)` | Open sockets / auth sessions |
| `toggle(bool)` | Power on/off |
| `setBrightness(double)` | 0.0–1.0 |
| `setColorTemperature(int)` | Kelvin |
| `setColor(int r, int g, int b)` | RGB |
| `getPowerStatus()` | Returns current on/off state |
| `getBrightness()` | Returns current brightness |
| `getDeviceInfo()` | Returns raw device metadata |
| `dispose()` | Release resources |

### `DriverManager`

- `registerDriver(driver)` — register a driver prototype at startup
- `bindDevice(device)` — resolves the correct driver by brand, initialises it, caches it by device ID
- `toggle / setBrightness / …` — command methods that route to the bound driver

### Adding a New Driver (Developer Mode)

1. Create `lib/drivers/<brand>/<brand>_driver.dart` extending `BaseDeviceDriver`.
2. Register it in `driverManagerProvider` inside `lib/features/devices/presentation/providers/device_provider.dart`.
3. It will automatically appear in the **Developer Mode** screen where you can fill in its JSON config schema.

---

## Protocol Details

### Kasa (local TCP + XOR cipher)

`KasaDriver` uses a raw TCP socket on port 9999.  
The payload is encrypted with the **XOR autokey cipher** (starting key = **171 = 0xAB**):

```
cipher[i] = plain[i] ^ key
key       = cipher[i]      // autokey: next key = previous ciphertext byte
```

The first 4 bytes of every message are a big-endian uint32 length header.

### Cync & Leviton (Cloud Bridge)

Both drivers authenticate using the brand's private OAuth2-style API (Resource Owner Password flow), then send REST commands via the `dio` HTTP client.  
Credentials are stored in `DeviceModel.extraConfig` and rendered via the **DriverConfigScreen** in Developer Mode.

### Matter

`MatterDriver` delegates all commands to the native platform via a Flutter `MethodChannel` (`com.iotmanager/matter`). The native side (Kotlin / Swift) is responsible for commissioning and sending Matter cluster commands.

### mDNS Discovery

`DiscoveryDriver` uses the `bonsoir` package to browse for `_tplink._tcp`, `_matterc._tcp`, `_matter._tcp`, `_hap._tcp`, and `_http._tcp` services simultaneously.

---

## Firebase Setup

1. Create a Firebase project at <https://console.firebase.google.com>.
2. Enable **Authentication** (Email/Password + Google Sign-In) and **Firestore**.
3. Run `flutterfire configure` to generate real `firebase_options.dart`.
4. Place `google-services.json` in `android/app/` and `GoogleService-Info.plist` in `ios/Runner/`.
5. Update `android/app/src/main/res/values/strings.xml` with your OAuth web client ID.

**Firestore data model:**

```
users/{uid}/devices/{deviceId}
  displayName: String
  brand: String           // kasa | cync | leviton | matter
  type: String            // smartPlug | dimmerSwitch | colorBulb | sensor
  ipAddress: String?      // local devices
  macAddress: String?
  model: String?
  extraConfig: Map        // brand-specific keys (API tokens, mesh keys…)
  isOnline: bool
  isPoweredOn: bool
  brightness: double?     // 0.0 – 1.0
  createdAt: Timestamp
  updatedAt: Timestamp
```

---

## Getting Started

```bash
# Install Flutter (https://flutter.dev/docs/get-started/install)
flutter pub get
flutter run
```

---

## Running Tests

```bash
flutter test
```

The test suite covers:
- `KasaDriver` XOR cipher (encrypt / decrypt round-trips, known vectors)
- `DriverManager` registration, binding, command routing, and error cases
- `DeviceModel` equality, `copyWith`, and Firestore serialisation
