# Antigravity & AI Agent Instructions — Flutter-RxDart-Base Workspace

This repository is the Mason Workspace source repository providing templates, bricks, tooling, and the custom linter for the **Flutter RxDart Base Architecture**.

## 🧭 Repository Layout

```
.
├── bricks/
│   ├── project/                  # Scaffolds initial Flutter app architecture (v1.4.0)
│   ├── bloc/                     # Scaffolds feature modules with BLoC and tests (v1.2.0)
│   └── harness/                  # Scaffolds AI Agent Harness onto apps (v1.6.1)
├── packages/
│   └── redux_rxdart_lints/       # Custom lint package enforcing golden rules (v0.2.0)
├── tool/
│   ├── smoke.dart                # E2E: create -> project -> bloc -> strict format -> analyze -> test -> lint
│   ├── docs_check.dart           # Validates markdown links
│   ├── harness_check.dart        # Harness docs may only reference generated paths/types/lint rules
│   ├── test_harness_upgrade.dart # E2E test of the harness's scripts/agent/upgrade.dart
│   └── version_gate.dart         # Version bump + CHANGELOG entry required for shipped changes
├── docs/                         # Extended architectural guides, brick references, and roadmap
└── .github/workflows/            # ci.yml, version-gate.yml, docs.yml, dependency-audit.yml, dependency-gate.yml
```

## ⚡ Maintainer Verification Quality Gates

Run these commands before committing any changes:

1. **Docs Link Integrity**:
   ```bash
   dart run tool/docs_check.dart
   ```
2. **Full E2E Generation Smoke Test**:
   ```bash
   dart run tool/smoke.dart
   ```
3. **Linter Package Analysis + Rule Fixtures**:
   ```bash
   dart analyze --fatal-infos packages/redux_rxdart_lints
   (cd packages/redux_rxdart_lints/example && flutter pub get && dart run custom_lint)
   ```
4. **Workspace Formatting & Code Analysis** (brick templates are excluded; they are checked through the smoke test):
   ```bash
   dart format --set-exit-if-changed tool bricks/project/hooks bricks/bloc/hooks
   dart analyze --fatal-infos tool bricks/project/hooks bricks/bloc/hooks
   ```
5. **Harness Checks**:
   ```bash
   dart run tool/harness_check.dart
   dart run tool/test_harness_upgrade.dart
   dart run tool/version_gate.dart origin/main
   ```

## 🔒 Maintainer Rules

1. **Brick Versioning & CHANGELOG**: Every template or hook change to a brick requires bumping `version` in its `brick.yaml` and documenting changes in that brick's `CHANGELOG.md`.
2. **Documentation Currency**: Keep `README.md`, `docs/`, and brick documentation synchronized with template changes.
3. **Golden Rules Consistency**: Enforceable Golden Rules in `bricks/harness/__brick__/AGENTS.md` must be mirrored in `packages/redux_rxdart_lints`, with an `expect_lint` case in its `example/` fixture.
4. **Canonical Repo vs Fork URLs**: Upstream is `TheJenilDGohel/Flutter-RxDart-Base`. Some functional URLs deliberately point at the fork `jenilseawind-glitch` until upstream merges the 1.6 work — do not "fix" them early, and switch them right after the upstream merge. See [`docs/contributing.md` §6](docs/contributing.md#6-urls-point-at-one-canonical-org).
5. **Git Commit Policy**: Conventional Commits format (`feat(...)`, `fix(...)`, `docs(...)`). Never commit without explicit instruction.

See [`docs/contributing.md`](docs/contributing.md) for complete maintainer details.
