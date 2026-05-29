<p align="center">
  <img src="assets/images/logo.png" alt="Sanchita Logo" width="120" height="120"/>
</p>

<h1 align="center">Sanchita</h1>

<p align="center">
  <em>Your personal finance companion — track, budget, and grow.</em>
</p>

<p align="center">
  <a href="https://github.com/Avishekdevnath/Sachita/actions/workflows/ci.yml">
    <img src="https://github.com/Avishekdevnath/Sachita/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  </a>
  <a href="https://github.com/Avishekdevnath/Sachita/releases/latest">
    <img src="https://img.shields.io/github/v/release/Avishekdevnath/Sachita?label=latest%20release&color=1F6E6E" alt="Latest Release"/>
  </a>
  <a href="https://github.com/Avishekdevnath/Sachita/releases/latest">
    <img src="https://img.shields.io/github/downloads/Avishekdevnath/Sachita/total?color=D4AF37" alt="Downloads"/>
  </a>
  <img src="https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white" alt="Platform"/>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="License"/>
</p>

---

## What is Sanchita?

**Sanchita** is a privacy-first personal finance app built with Flutter. All your data lives on your device — no cloud, no subscriptions, no tracking. It helps you record daily expenses and income, set monthly budgets, track recurring payments, and store important financial documents — all secured behind biometric authentication and a PIN.

---

## Features

### Money Management
- **Transactions** — Record income and expenses with categories, notes (supports full shopping/bazar lists), and dates
- **Monthly Summary** — Visual breakdown of spending by category with daily trend charts
- **Budget Management** — Set monthly limits per category with progress tracking and overspend alerts
- **Recurring Rules** — Automate regular payments (rent, subscriptions, salary) with custom frequencies

### Security
- **Biometric Auth** — Fingerprint / face unlock on supported devices
- **PIN Protection** — 4–6 digit PIN as fallback
- **Security Question** — Recovery fallback if PIN is forgotten

### Vault *(coming soon)*
- Store scanned documents, bills, and financial records
- Organize by folders with metadata tagging

### Groups *(coming soon)*
- Shared expense tracking for families or flatmates
- Split costs and settle balances

### UI & Experience
- **Material 3** design with teal + gold brand palette
- **Dark & Light theme** with one-tap toggle
- **Offline-first** — fully functional without internet
- **Auto-update** — notified when a new version is available on GitHub Releases

---

## Download

<p align="center">
  <a href="https://github.com/Avishekdevnath/Sachita/releases/latest">
    <img src="https://img.shields.io/badge/⬇ Download%20APK-GitHub%20Releases-1F6E6E?style=for-the-badge&logo=github&logoColor=white" alt="Download APK"/>
  </a>
</p>

### Install Steps

1. Go to [Releases](https://github.com/Avishekdevnath/Sachita/releases/latest)
2. Download `sanchita.apk`
3. On your Android device, go to **Settings → Install unknown apps** and allow your browser or file manager
4. Open the downloaded APK and tap **Install**
5. Launch **Sanchita** and complete the one-time setup

> **Minimum Android version:** Android 6.0 (API 23)

---

## Screenshots

> *Coming soon — screenshots will be added with the first public release.*

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x + Dart 3.x |
| State Management | Riverpod (flutter_riverpod) |
| Navigation | GoRouter |
| Local Database | SQLite via sqflite |
| Authentication | local_auth (biometric) |
| Theme | Material 3, custom ColorScheme + ThemeExtension |
| CI/CD | GitHub Actions |
| Release | Signed APK via GitHub Releases |

---

## For Developers

### Prerequisites

- Flutter SDK `3.x` (stable channel)
- Java 17 (for Android build)
- Android SDK / Android Studio

### Setup

```bash
git clone https://github.com/Avishekdevnath/Sachita.git
cd Sachita
flutter pub get
flutter run
```

### Build Release APK (local)

1. Copy the keystore template:
   ```bash
   cp android/key.properties.example android/key.properties
   ```
2. Fill in your keystore details in `android/key.properties`
3. Place your `.jks` file at `android/sanchita-release.jks`
4. Build:
   ```bash
   flutter build apk --release
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`

### Run Tests

```bash
flutter test
flutter analyze
```

---

## CI/CD

Every push to `main` or `develop` runs **analyze + test** automatically.

To publish a new release:

```bash
git tag v1.0.1
git push origin v1.0.1
```

GitHub Actions will:
1. Build a signed APK
2. Upload it as `sanchita.apk` to a new GitHub Release
3. Update `version.json` so the app can notify users of the update

---

## Version Updates

The app checks `version.json` in this repository on each launch. When a newer version is available, users see a non-intrusive update prompt with a direct download link. No Play Store required.

---

## Privacy

Sanchita stores **all data locally on your device**. Nothing is uploaded, synced, or shared with any server. The app requires no internet permission for core functionality — network access is only used to check for app updates from this repository.

---

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes
4. Push and open a Pull Request

---

## License

MIT © [Avishek Devnath](https://github.com/Avishekdevnath)

---

<p align="center">
  Built with ❤️ using Flutter
</p>
