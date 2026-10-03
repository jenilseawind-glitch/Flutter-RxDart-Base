# `harness` Brick

Makes AI coding agents (Claude Code, Codex, Cursor, Copilot, Gemini CLI, ...) build your app the way this architecture expects, and get better at it over time. Installed by `project` when `include_harness` is on (the default), or on its own:

```bash
mason make harness --project_name my_app \
  --android_package_name com.acme.my_app --ios_bundle_id com.acme.my-app
```

The brick has no hooks and does not edit `pubspec.yaml`. `project` adds `custom_lint` and `redux_rxdart_lints`; on an existing project, add them yourself (see [`redux_rxdart_lints`](../packages/redux_rxdart_lints.md)).

---

## What your app gets

| Path | What it does |
|---|---|
| `AGENTS.md` | The rulebook every agent reads: architecture, 13 golden rules (🔒 = enforced by lints), skill index, tooling, memory. Everything below the `harness:project-rules` marker is yours. |
| `CLAUDE.md` | Claude Code's entry: imports `AGENTS.md`, adds the app ids, loads `.harness/active-context.md`. |
| `.agents/skills/` | Eight skills, one per kind of work (table below). Claude Code reads the entry points in `.claude/skills/`. |
| `scripts/agent/verify.dart` | The quality gate: format → analyze → architecture lints → tests → lessons → snapshot (`--fast` = format + analyze). |
| `scripts/agent/wire_route.dart` | Scaffolds a feature with `mason make bloc` if missing, then adds its route. |
| `scripts/agent/learn.dart` | The lessons loop (below). |
| `scripts/agent/upgrade.dart` | Upgrades the harness without touching your work (below). |
| `.claude/` | Settings (edit hook, allowlist), skill entry points, the `flutter-qa` review subagent. |
| `.mcp.json`, `.cursor/mcp.json` | The Dart & Flutter MCP server: analyzer, symbols, pub.dev, hot reload, runtime errors, widget tree. |
| `.harness/` | Memory: `active-context.md`, `progress.md`, `lessons.md`, generated `system-snapshot.md`, `version.json`. Agents add skill overlays (`skills/<skill>.md`) and specs (`specs/<feature>.md`). |

### Skills

| Skill | Use it for |
|---|---|
| `add-feature` | A new screen or flow: contract → spec → scaffold → layers → tests → gate |
| `add-endpoint` | Any API work: transport-only repo, defensive model, BLoC call, tests with real JSON |
| `manage-state` | Where state lives; BLoC recipes (submit, search, pagination, events, several loads, timers); Redux changes |
| `build-ui` | Page/content split, tokens, ScreenUtil, l10n, shared widgets, dialogs, accessibility |
| `write-tests` | BLoC, model, widget, reducer and regression tests |
| `fix-bug` | Symptom → layer table, every gate step and lint rule |
| `evolve-harness` | The lessons loop and project skills |
| `flutter-senior-dev` | Planning, architecture decisions, review |

Codex, Gemini CLI and OpenCode read `.agents/skills/`. Claude Code reads only `.claude/skills/`, so each skill has a small entry point there. Cursor reads both folders and may list each skill twice.

### The lessons loop

Each skill starts by loading what the project has learned and ends by recording what a future agent would otherwise get wrong:

```bash
dart run scripts/agent/learn.dart list add-endpoint     # start of a task
dart run scripts/agent/learn.dart add add-endpoint "Orders API dates are epoch seconds: use fromMillisecondsSinceEpoch" --proof commit:a1b2c3d
dart run scripts/agent/learn.dart review                # seen twice? promote it
```

A lesson seen twice is promoted into a skill overlay, a rule in `AGENTS.md` §7, a new project skill, or `upstream` for the base repository (`learn.dart upstream` prints those). A promoted lesson that happens again reopens. `learn.dart` refuses secrets and injected instructions, and `verify` fails on credentials in any memory file.

---

## Upgrading

```bash
dart run scripts/agent/upgrade.dart                 # latest upstream release
dart run scripts/agent/upgrade.dart --check-only    # just report
```

- **What it renders:** the harness from `upstream_repo` in `.harness/version.json`, in a throwaway mason workspace. A `mason.yaml` pin in your project or a stale `mason add -g` copy can't hold you back. `--ref <git-ref>` picks a branch, tag or commit; `--brick <dir>` uses a local brick. Offline, it falls back to your registered brick and says so.
- **What it changes:** every file the brick ships in `scripts/agent/` and the shipped skills, the QA subagent, and the part of `AGENTS.md`/`CLAUDE.md` above the marker.
- **What it keeps:** `.harness/` (memory, lessons, overlays, specs), skills you created, everything below the marker, your `.claude/settings.json` and `.mcp.json` (it lists what they lack, and hooks that run missing scripts), and any file in `scripts/agent/` it doesn't ship.
- **Safety:** nothing changes unless rendering succeeds; every touched file is backed up to `.harness/.backup_<timestamp>/` (last three kept); it never downgrades without `--force`; when the new version ships a different `upgrade.dart`, the new one applies the upgrade.
- Pre-1.6 `AGENTS.md`/`CLAUDE.md` (no marker): every line no harness template contained is kept below the marker, under "Kept from your previous version of this file".

### Upgrading from 1.7.0 or older

The installed `upgrade.dart` runs the upgrade, and engines up to 1.7.0 render whichever `harness` brick mason resolves (your project's `mason.yaml` pin first), replace `scripts/agent/` wholesale, and drop team lines from pre-1.6 contracts. Install the current engine first, then run it:

```bash
curl -sSL https://raw.githubusercontent.com/jenilseawind-glitch/Flutter-RxDart-Base/main/bricks/harness/__brick__/scripts/agent/upgrade.dart -o scripts/agent/upgrade.dart
dart run scripts/agent/upgrade.dart
```

Your app ids come from `.harness/version.json` (or, for old projects, `CLAUDE.md` and the platform files), never a `com.example` guess. After upgrading, add `"Bash(dart run scripts/agent/learn.dart:*)"` to `.claude/settings.json` if the upgrade lists it.

---

See [`CHANGELOG.md`](https://github.com/jenilseawind-glitch/Flutter-RxDart-Base/blob/main/bricks/harness/CHANGELOG.md) for version history.
