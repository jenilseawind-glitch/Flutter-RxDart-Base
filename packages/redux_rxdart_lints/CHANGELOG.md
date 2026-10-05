# Changelog

## 0.3.0

- Added `no_exception_tostring` rule enforcing Golden Rule #2: Widgets must show errors with `error.userFacingMessage(context)` instead of displaying `e.toString()`.

## 0.2.1

- SDK floor lowered to Dart ≥ 3.9 (what `analyzer ^8.4` needs). 0.2.0 required Dart ≥ 3.13, which blocked projects on Flutter ≤ 3.44.

## 0.2.0

- All rules match on the path relative to `lib/` instead of the absolute path, fixing false positives/negatives caused by checkout location (e.g. a CI workspace named `/repo/`, or a parent folder named `utils/`).
- `no_rxdart_in_ui`: `utils/widgets/` is now checked (it is UI); `networking/` and `services/` are allowed; `export` directives are checked too.
- `no_setstate_in_widget`: only flags calls resolving to Flutter's `State.setState`; the `utils/widgets/ui/` exemption is now documented.
- `repo_transport_only`: also flags `fromMap`, constructor and static tear-offs (`.map(Model.fromJson)`), and `*_repo.dart` / `*_repository.dart` / `repository/` files.
- `no_screenutil_in_private_widget`: only flags extensions declared by `flutter_screenutil`; detects any private `Widget` subtype (e.g. `ConsumerWidget`, `HookWidget`) through the type hierarchy.
- Added the `example/` fixture project with `expect_lint` cases for every rule, run in CI. Removed the never-executed `test/no_set_state_test.dart`.
- Dart SDK floor `^3.13.0`.

## 0.1.0

- Initial rules: `no_rxdart_in_ui`, `no_setstate_in_widget`, `repo_transport_only`, `no_screenutil_in_private_widget`.
