# redux_rxdart_lints

`custom_lint` plugin enforcing the Redux+RxDart+Dio architecture golden rules
documented in the harness's `AGENTS.md`, at `dart analyze` time instead of
relying on an AI agent (or human) remembering them.

## Rules

All path checks use the path **relative to `lib/`**, so results never depend
on where the project is checked out.

| Rule | Golden Rule | Flags |
|---|---|---|
| `no_rxdart_in_ui` | #4 Zero RxDart Outside BLoC | `import`/`export` of `package:rxdart/...` anywhere except `bloc/` folders, `*_bloc.dart`, `redux/`, `networking/`, `services/` and non-widget `utils/` (`utils/widgets/` is UI and is checked) |
| `no_setstate_in_widget` | #3 Zero setState | calls that resolve to Flutter's `State.setState`. Design-system primitives in `lib/utils/widgets/ui/` are exempt (purely visual state) |
| `no_screenutil_in_private_widget` | Adaptive layout (ScreenUtil) | `flutter_screenutil` extensions (`.w .h .r .sp ...`, resolved to the package — your own `.w` extension is ignored) inside a private (`_Foo`) widget of any kind, or the `State` of one. ScreenUtil 5.9.x does not rebuild private widgets on resize |
| `repo_transport_only` | #1 Repository is Transport ONLY | `fromJson` / `fromMap` calls **and tear-offs** (`.map(Model.fromJson)`) in a repository: files under `repo/` or `repository/`, or named `*_repo.dart` / `*_repository.dart` |

## Testing

`example/` is a fixture Flutter project. Lines that must be flagged carry
`// expect_lint: <rule>`; every other line must stay clean, and
`custom_lint` fails on a missing *or* an unexpected lint:

```bash
cd example
flutter pub get
dart run custom_lint
```

CI runs this on every push. Add a positive and a negative case to the
fixture with every rule change.

## Usage

In the consuming Flutter project's `pubspec.yaml`:

```yaml
dev_dependencies:
  custom_lint: ^0.8.1
  redux_rxdart_lints:
    git:
      url: https://github.com/jenilseawind-glitch/Flutter-RxDart-Base.git
      path: packages/redux_rxdart_lints
```

In `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

Then `flutter pub get`. Findings appear in the IDE through the analysis
server. On the command line, run `dart run custom_lint` (plain
`flutter analyze` does **not** run custom_lint plugins); the harness's
`scripts/agent/verify.sh` / `verify.ps1` already do.
