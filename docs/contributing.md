# Maintainer Rules

Rules for changing this workspace: `bricks/project`, `bricks/bloc`, `bricks/harness`,
`packages/redux_rxdart_lints`.

## 1. Every behavior change to a Brick bumps its version + CHANGELOG

If you touch `hooks/pre_gen.dart`, `hooks/post_gen.dart`, or any file under `__brick__/` in a way
that changes generated output or hook behavior:

- Bump `version:` in that brick's `brick.yaml` (semver — patch for fixes, minor for new
  capabilities, major for breaking template/var changes).
- Add an entry to that brick's `CHANGELOG.md` (`bricks/project/CHANGELOG.md`, `bricks/bloc/CHANGELOG.md`, and `bricks/harness/CHANGELOG.md` are all actively maintained).

Cosmetic-only changes (formatting, comments) don't require a bump.

## 2. README is documentation, not a changelog — but it must not go stale

Every README (`README.md`, `bricks/*/README.md`, `packages/*/README.md`) documents *current*
generated output and hook behavior. When you change what a hook does or what a template
generates, update the README in the same change — don't defer it.

This bit us once already: `bricks/project/hooks/post_gen.dart` had `flutter gen-l10n` and the
`mason make harness` auto-install step added without `bricks/project/README.md`'s "Hook Execution
Summary" being updated to match. Don't let that gap reopen — grep the relevant README before
calling a hook/template change done.

## 3. New Brick checklist

- `brick.yaml` (name, description, version, mason environment constraint).
- `__brick__/` templates.
- `hooks/pre_gen.dart` / `post_gen.dart` only if needed — don't add hooks with no behavior.
- `README.md` — usage, prompted vars table, what gets generated, hook execution summary.
- Register it in root `mason.yaml`.
- Add a row to the root `README.md`'s "Mason Bricks at a Glance" table.

## 4. Golden Rules changes propagate to the lint plugin

If you change a Golden Rule in `bricks/harness/__brick__/AGENTS.md` that's mechanically
enforceable (repo-transport-only, zero setState, zero RxDart outside BLoC, or a new one), update
the matching rule in `packages/redux_rxdart_lints/lib/src/rules/`. A rule documented in AGENTS.md
but not enforced by the plugin is a silent drift risk — either enforce it or don't claim it's
analyzer-enforced.

## 5. Verify before committing

- **Docs & Link Integrity**: Run `dart run tool/docs_check.dart` from the repository root. Validates that all relative links and cross-references in `README.md`, `docs/`, and brick documentation resolve to real files.
- **Full E2E Smoke Test**: Run `dart run tool/smoke.dart` from the repository root. Exercises the full end-to-end flow: `flutter create` -> `mason make project` -> `mason make bloc` -> `dart format` -> `flutter analyze` -> `flutter test` -> `custom_lint`.
- **Linter Package Analysis**: Run `dart analyze --fatal-infos` inside `packages/redux_rxdart_lints/`.
- **Formatting & Analysis**: Run `dart format --set-exit-if-changed .` and `dart analyze` across all touched packages and hook directories (`bricks/*/hooks/`).
- If you change `wire_route.dart` or a hook's file-injection logic, dry-run it against the real
  templates in a scratch copy before trusting the regex — don't assume it's correct from reading
  it. (Silent no-ops in generated/injected files are the failure mode to watch for.)

## 6. URLs point at one canonical org

The canonical repository is **`https://github.com/TheJenilDGohel/Flutter-RxDart-Base.git`**
(the upstream). All git-dependency URLs, `mason add -g --git-url` examples and README links
should use it. If the working remote (`git remote -v`) differs, ask before writing new URLs;
don't guess.

### Temporary exception: fork URLs until upstream merges

Development currently happens in the fork `jenilseawind-glitch/Flutter-RxDart-Base`, which is
ahead of upstream (project 1.4.0, bloc 1.2.0, harness 1.6.0, `redux_rxdart_lints` 0.2.0 on
analyzer 8). Upstream `main` still ships `redux_rxdart_lints` 0.1.0 on analyzer 7 /
`custom_lint_builder ^0.7`, which conflicts with the template's `custom_lint ^0.8.1` and crashes
on Flutter 3.47. Pointing generated apps at upstream today would break `flutter pub get` in
every new project, so these **functional** URLs intentionally name the fork:

| File | What depends on it |
|---|---|
| `bricks/project/__brick__/pubspec.yaml` | `redux_rxdart_lints` git dependency of every generated app |
| `bricks/harness/__brick__/.harness/version.json` | `upstream_repo` used by `upgrade.dart` |
| `bricks/harness/__brick__/scripts/agent/upgrade.dart` | fallback `upstream` URL (`--check-only`, `mason add` hint) |
| `packages/redux_rxdart_lints/README.md`, `docs/packages/redux_rxdart_lints.md` | install snippet |
| `docs/bricks/bloc.md`, `docs/bricks/harness.md` | CHANGELOG links |

**After this work is merged into `TheJenilDGohel/Flutter-RxDart-Base` (maintainer or AI agent):**

1. `grep -rn "jenilseawind-glitch" --exclude-dir=.git .` — every hit is in the table above.
2. Replace each with `TheJenilDGohel`, delete this subsection, and remove the
   `fork-url:` comments next to the URLs (`grep -rn "fork-url"`).
3. Bump `project` and `harness` (patch) with a CHANGELOG line: "URLs point at the canonical
   upstream repository."
4. Run the gates in `AGENTS.md`. `tool/smoke.dart` accepts either org, so it stays green.

## 7. Commit policy

Per `AGENTS.md` Golden Rule (section 6): never commit unprompted. Conventional Commits format
(`feat(bricks): ...`, `fix(harness): ...`) with rationale, only when explicitly asked.
