# redux_rxdart_lints fixture

Each file under `lib/` exercises one rule. Lines that must be flagged carry
`// expect_lint: <rule>`; everything else must stay clean. `custom_lint`
fails on a missing expected lint *and* on an unexpected one:

```bash
flutter pub get
dart run custom_lint
```
