# `harness` Brick

Scaffolds an AI agent harness onto a Flutter project built on this base: one
cross-tool contract (`AGENTS.md`), eight [Agent Skills](https://agentskills.io)
that carry the procedure for each kind of work, a learning loop that turns
every session's mistakes into lessons the next session loads, native wiring for
Claude Code (memory import, skills, QA subagent, an edit hook and a permission
allowlist), the official Dart & Flutter MCP server, a cross-platform quality
gate, and project memory that survives sessions and harness upgrades. Installed
automatically by `project` (`include_harness`), or standalone.

---

## 📋 Usage

```bash
mason make harness --project_name my_app \
  --android_package_name com.acme.my_app --ios_bundle_id com.acme.my-app
```

The ids are written into `CLAUDE.md` and recorded in `.harness/version.json`
so upgrades reuse them. The brick has no hooks; it does **not** edit
`pubspec.yaml` — the `project` brick adds `custom_lint` and
`redux_rxdart_lints` when `include_harness` is on. On an existing project,
add them yourself (see [`redux_rxdart_lints`](../../packages/redux_rxdart_lints/README.md)).

---

## 🏗️ What Gets Generated

| Path | For | What it does |
|---|---|---|
| `AGENTS.md` | every agent | The contract: architecture, 13 golden rules (🔒 = lint-enforced), API-discovery order, skill index and tooling, git policy, memory and learning protocol. Everything below the `harness:project-rules` marker belongs to the team and survives upgrades. |
| `CLAUDE.md` | Claude Code | Imports `@AGENTS.md`, adds Claude-specific notes and app ids, transcludes `.harness/active-context.md`. |
| `.claude/settings.json` | Claude Code | `PostToolUse` hook → `scripts/agent/on_edit.dart`; allowlist for format/analyze/test/verify/learn/`mason make bloc` and the `dart` MCP server; force-push denied. |
| `.claude/skills/<skill>/` | Claude Code | One entry point per skill, loading the shared copy below. |
| `.claude/agents/flutter-qa.md` | Claude Code | One-shot review subagent: runs the gate, checks what tools can't, suggests lessons. |
| `.agents/skills/<skill>/` | Codex, Cursor, Gemini CLI, OpenCode, ... | The eight shared skills (table below). |
| `.mcp.json`, `.cursor/mcp.json` | MCP clients | Registers `dart mcp-server` (ships with the Dart SDK): analyzer, LSP, pub.dev search, and hot reload / runtime errors / widget inspector on a running app. |
| `scripts/agent/verify.dart` (+ `.sh`/`.ps1`) | everyone, CI | Quality gate: format → analyze → custom lints → tests → lessons → snapshot. `--fast` for format + analyze. |
| `scripts/agent/learn.dart` | everyone | The learning loop over `.harness/lessons.md`: `list`, `add`, `hit`, `promote`, `retire`, `review`, `upstream`, `check`. |
| `scripts/agent/on_edit.dart` | hook | Formats and analyzes the edited Dart file; reports issues back to the agent (exit 2). |
| `scripts/agent/wire_route.dart` | everyone | Scaffolds a feature with `mason make bloc` if missing and wires its route. Refuses to guess with `go_router` / `auto_route`. |
| `scripts/agent/snapshot.dart` | memory | Deterministic `.harness/system-snapshot.md`: features (and which lack tests), routes, endpoints, `AppState` fields, dependencies. |
| `scripts/agent/upgrade.dart` | maintainers | Upgrades the harness in place (below). |
| `.harness/` | memory | `active-context.md` (agent-maintained, capped), `progress.md` (append-only log), `lessons.md` (learning loop), `version.json` (version, ids, managed skills, upgrade history). Agents add `skills/<skill>.md` overlays and `specs/<feature>.md` specs here. |

---

## 🧠 Skills and the Learning Loop

| Skill | Use it for |
|---|---|
| `flutter-senior-dev` | Planning, architecture decisions, user journeys, code review. Routes hands-on work to the task skills. |
| `add-feature` | A new screen or flow end to end: contract → spec with acceptance criteria → `wire_route.dart` → layers → tests → gate. |
| `add-endpoint` | Any API work: contract, `ApiConstants`, transport-only repo, defensive model, BLoC call, tests with real JSON. |
| `manage-state` | Where state lives; BLoC recipes (submit, live search, pagination, events, several loads, dependent calls, local UI state, timers); Redux session changes. |
| `build-ui` | Page/content split, tokens, ScreenUtil, l10n, shared widgets, dialogs, toasts, accessibility. |
| `write-tests` | BLoC, model, widget, reducer and regression tests. |
| `fix-bug` | Symptom → layer table, every gate step and lint rule, regression test, lesson. |
| `evolve-harness` | The loop below: capture, recall, promote, prune, upstream; authoring project skills. |

**Discovery.** Codex, Gemini CLI and OpenCode read `.agents/skills/`. Claude Code reads only `.claude/skills/`, so each skill has a small entry point there with the same name and description, pointing at the shared copy. Cursor reads both folders and may list each skill twice; both copies lead to the same instructions. Agents without skill support still get the index in `AGENTS.md` §4.

Every task skill starts by loading what the project has learned (its overlay `.harness/skills/<skill>.md` plus `learn.dart list <skill>`) and ends with the close-out in `AGENTS.md` §6:

1. **Capture**: a gate that needed several attempts, a user correction, a backend quirk or a wrong skill step becomes one line, recorded with `learn.dart add <skill> "<trigger>: <fix>" --proof <ref>`, or counted again with `learn.dart hit L<id>`.
2. **Promote**: `verify` reports lessons seen twice. `learn.dart review` suggests a target: a skill overlay, a project rule in `AGENTS.md` §7, a new project skill, or `upstream`.
3. **Self-correct**: a promoted lesson that happens again reopens, because its rule didn't work.
4. **Upstream**: `learn.dart upstream` prints harness-level lessons to file with the base repository, so the next harness release (and every app's `upgrade.dart`) carries them.

Everything the loop writes lives in `.harness/` or below the `AGENTS.md` marker, so upgrades never erase what a project has learned. Because lessons are loaded into every future session, `learn.dart` refuses secrets (tokens, keys, credentialed URLs) and injected-instruction phrasing, and `verify` fails on credentials in any agent memory file. The skill allows lessons only from the agent's own verified work or the user's explicit instructions.

---

## 🔄 Upgrading an Existing Project

```bash
mason upgrade -g                       # refresh the registered harness brick
dart run scripts/agent/upgrade.dart    # --check-only / --force
```

1. **Managed** — `scripts/agent/`, the skills the brick ships (`managed_skills` in `version.json`) and the QA subagent are replaced. Skills your project created are never touched; a shipped skill the brick no longer ships is removed.
2. **Memory** — `.harness/` (active context, progress, lessons, skill overlays, specs) is never overwritten. Missing memory files are created, and one log line is added to Recent Tasks.
3. **Contracts** — `AGENTS.md` / `CLAUDE.md` get the new template above the `harness:project-rules` marker; everything below it is kept verbatim. Pre-1.6 files without the marker have their custom sections recovered and moved below it. Config you may have edited (`.claude/settings.json`, `.mcp.json`) is only added when missing. For an existing `settings.json`, the upgrade lists template permissions it lacks.

Nothing changes if the brick fails to render, a backup of every touched file goes to `.harness/.backup_<timestamp>/` (last three kept), and the app ids come from `version.json` (or, for older projects, the old `CLAUDE.md` / platform files) — never a `com.example` guess. `--check-only` writes `has_update` / `new_version` to `$GITHUB_OUTPUT` for CI.

---

### Upgrading a project from harness ≤ 1.5.x

Projects installed before 1.6.0 carry an old `upgrade.dart` that takes the "latest" version from git tags. The repository has no tags, so it always reports **"Harness is already up to date (version 1.5.0)"**. It cannot upgrade itself, so replace it once by hand:

```bash
# 1. Make mason render the current brick
mason add -g harness --git-url https://github.com/jenilseawind-glitch/Flutter-RxDart-Base.git --git-path bricks/harness
mason upgrade -g
# 2. Swap in the current upgrade engine
curl -sSL https://raw.githubusercontent.com/jenilseawind-glitch/Flutter-RxDart-Base/main/bricks/harness/__brick__/scripts/agent/upgrade.dart -o scripts/agent/upgrade.dart
# 3. Upgrade (memory, team sections and app ids are kept)
dart run scripts/agent/upgrade.dart
```

Don't run the old script with `--force`: its merge overwrites the app ids with `com.example.*` and duplicates the memory transclusion. From 1.6.1 on, `--check-only` reads the version from upstream's `brick.yaml`, and the script warns when your registered brick is older than upstream.

---

## ⚙️ Generation Architecture

`harness` v1.7.0 is a pure-template brick (zero hooks): everything renders
from `__brick__/`, so generation is instant and avoids the Windows `MAX_PATH`
issues that hook compilation caused in 1.3.x. Note that mason does not keep the
executable bit: run the wrapper as `bash scripts/agent/verify.sh`, or call
`dart run scripts/agent/verify.dart` directly.

See [`CHANGELOG.md`](CHANGELOG.md) for version history.
