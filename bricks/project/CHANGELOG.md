# Changelog

## 1.3.0

- **Dependency Upgrades**:
  - `connectivity_plus`: Upgraded from `^6.1.0` to `^7.3.1`. Adopted idiomatic `!result.hasConnectivity` in `ConnectivityInterceptor`.
  - `flutter_dotenv`: Upgraded from `^5.2.1` to `^6.0.1` with enhanced error diagnostics and multi-environment file overrides.
  - `flutter_secure_storage`: Upgraded from `^9.2.2` to `^10.3.4` (bridge version with automatic KeyStore cipher migration engine, Apple Privacy Manifest, and WASM compatibility).
- **Environment Baseline**:
  - Raised template Dart SDK constraint to `sdk: ">=3.3.0 <4.0.0"` to match Flutter 3.19+ and modern plugin ecosystem requirements.

### ⚠️ Pre-Upgrade Checklist (Before Upgrading Existing Projects)

When updating an existing app scaffolded with earlier versions of this brick:

1. **Android Build Configuration**:
   - Ensure Android Gradle Plugin (AGP) is `>= 8.12.1` and Gradle distribution wrapper is `>= 8.13`.
   - Ensure `compileOptions` specifies Java 17 compatibility.
   - Verify `minSdkVersion` is at least `21` (or `23` if using `flutter_secure_storage`).
2. **iOS / macOS Build Configuration**:
   - Ensure Xcode is `>= 16.1` and deployment target is at least **iOS 13.0** (`platform :ios, '13.0'` in `Podfile`) and **macOS 10.15**.
3. **Secure Storage Data Migration**:
   - Upgrading `flutter_secure_storage` to `10.3.4` will automatically re-encrypt legacy 9.x tokens using `RSA-OAEP` + `AES-GCM`.
   - **Do NOT bump directly to 11.x on published apps**, as 11.x deletes legacy ciphers without migration. Run on `10.3.x` first.
4. **Environment Variables**:
   - If using `flutter_dotenv` in tests, replace deprecated `dotenv.testLoad(...)` with `dotenv.loadFromString(...)`.

## 1.2.1

- Ensured `.env` template asset is explicitly tracked in repository for clean smoke test asset resolution.
- Added `analysis_options_deprecated_plugins: ignore` to scaffolded `analysis_options.yaml` to suppress Dart SDK legacy plugin deprecation warning on Flutter 3.27+.
- Upgraded `custom_lint` to `^0.8.0` to support Dart analyzer 7.5.0+ and prevent AST visitor crashes on Flutter 3.27+ runners.

## 1.2.0

- Upgraded deprecated `.withOpacity(...)` to Flutter 3.27+ `.withValues(alpha: ...)` across design tokens and UI components (`common_utils.dart`, `app_card.dart`, `app_dialog.dart`, `app_textformfield.dart`, `showcase_home_page.dart`).
- Added `Flexible` with `TextOverflow.ellipsis` to `CommonButton` label text to prevent `RenderFlex` overflow on narrow viewports.
- Enhanced `CancelTokenOwner.createNewToken()` to return the freshly instantiated `CancelToken`.
- Explicitly typed `ApiBaseHelper` network calls with `<dynamic>` to safely accommodate primitive and array JSON payloads.
- `post_gen.dart` passes `--android_package_name`, `--ios_bundle_id`, and `--on-conflict overwrite` when invoking `mason make harness`.
- Relaxed Dart SDK constraints to `>=3.0.0 <4.0.0` for broader Flutter 3.x compatibility.

## 1.1.0

- `post_gen.dart` now runs `flutter gen-l10n` after `flutter pub get` to generate localization
  classes from the scaffolded ARB files.
- Added `include_harness` boolean var (default `true`). When true, `post_gen.dart` auto-runs
  `mason make harness --project_name <name>` to scaffold the AI Agent Harness. Non-fatal if it
  fails — prints a note that it can be installed anytime via `mason make harness`.

## 1.0.0

- Initial release: Redux store, Dio HTTP/2 engine with 5-interceptor chain, design tokens,
  localization scaffold, showcase demo, package-name/bundle-id rename on generation.
