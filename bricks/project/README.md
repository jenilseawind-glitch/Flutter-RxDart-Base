# `project` Brick

Scaffolds a complete, production-grade Flutter architecture onto an **already-created** Flutter project.

---

## 📋 Usage

From inside your Flutter project directory (e.g. created via `flutter create my_app`):

```bash
mason make project
```

### Prompted Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `project_name` | String | Project name in `snake_case` (must match `flutter create` name) | `my_app` |
| `android_package_name` | String | Android reverse-domain package identifier | `com.example.myapp` |
| `ios_bundle_id` | String | iOS bundle identifier (defaults to `android_package_name` if blank) | `com.example.myapp` |
| `include_harness` | Boolean | Scaffold the [AI Agent Harness](../harness/README.md) (`AGENTS.md`, `CLAUDE.md`, `scripts/agent/`, analyzer-enforced golden rules) | `true` (default) |

---

## 🏗️ What Gets Generated

- **`lib/redux/`**: `AppState`, `AppAction`, reducer, `AppStore` hydration, logging & persistence middleware.
- **`lib/networking/`**: `ApiBaseHelper`, `DioClient`, 5-interceptor chain, sealed `ApiException`, sealed `ApiResponse<T>`.
- **`lib/resources/`**: Design tokens (`ResColors`, Material 3 `AppTypography` with ScreenUtil `.sp`).
- **`lib/utils/`**: `AppScaffold`, core UI states (`AppLoadingState`, `AppErrorState`, `AppEmptyState`), `AppRouter`, `ShowMessage` toasts, `CommonUtils`, context & string extensions.
- **`lib/features/`**: The home for your actual app features (generated via `mason make bloc`).
- **`lib/services/`**: Notification and device info stubs.
- **`lib/l10n/`**: Localization setup (`app_en.arb`, `app_hi.arb`, `l10n.yaml`).
- **`lib/main.dart`**: Complete entry point with Redux hydration, ScreenUtil, AppRouter, and OverlaySupport.

---

## ⚙️ Hook Execution Summary

All dependencies (`dio`, `redux`, `rxdart`, `flutter_localizations`, `generate: true`,
dev-deps like `change_app_package_name`, etc.) ship pre-declared in `__brick__/pubspec.yaml` —
no dependency injection happens at generation time.

### `post_gen.dart`
- Verifies `android/` and `ios/` directories exist (confirms `flutter create` was run first).
- Runs `flutter pub get`.
- Runs `flutter gen-l10n` to generate localization classes from the scaffolded ARB files.
- Runs package rename via `change_app_package_name` using `android_package_name`.
- Warns if `ios_bundle_id` differs from `android_package_name` (manual `project.pbxproj` follow-up).
- If `include_harness` is true (default), runs `mason make harness --project_name <name>` to
  scaffold the AI Agent Harness. Non-fatal if it fails — prints a note that it can be installed
  anytime via `mason make harness`.

---

## ⚠️ Pre-Upgrade Checklist for Existing Apps

When updating an existing app scaffolded with an earlier version of this brick:

1. **Check Native Toolchains**:
   - **Android**: Ensure AGP `>= 8.12.1`, Gradle `>= 8.13`, Java 17, and `minSdkVersion >= 21` (or `23` with secure storage).
   - **iOS / macOS**: Ensure Xcode `>= 16.1` and minimum deployment targets **iOS 13.0** and **macOS 10.15**.
2. **Secure Storage Migration Safety**:
   - `flutter_secure_storage` is set to `^10.3.4` (bridge release). When launched, it automatically re-encrypts 9.x legacy ciphers to `RSA-OAEP` + `AES-GCM`.
   - **Do NOT bump directly to 11.x on published apps**, as 11.x deletes legacy ciphers without migration. Run on `10.3.x` first.
3. **Environment Variables**:
   - In test files, replace legacy `dotenv.testLoad(...)` with `dotenv.loadFromString(...)`.

See [`CHANGELOG.md`](CHANGELOG.md) for version history.
