# `harness` Brick

Scaffolds an AI agent harness onto a Flutter project built on this base: one
cross-tool contract (`AGENTS.md`), native wiring for Claude Code (memory import,
skill, QA subagent, an edit hook and a permission allowlist), the official Dart &
Flutter MCP server for every MCP-capable agent, a cross-platform quality gate,
and project memory that survives sessions and harness upgrades. Installed
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
add them yourself (see [`redux_rxdart_lints`](../packages/redux_rxdart_lints.md)).

---

## 🏗️ What Gets Generated

| Path | For | What it does |
|---|---|---|
| `AGENTS.md` | every agent | The contract: architecture, 13 golden rules (🔒 = lint-enforced), API-discovery order, tooling, git policy, memory protocol. Everything below the `harness:project-rules` marker belongs to the team and survives upgrades. |
| `CLAUDE.md` | Claude Code | Imports `@AGENTS.md`, adds Claude-specific notes and app ids, transcludes `.harness/active-context.md`. |
| `.claude/settings.json` | Claude Code | `PostToolUse` hook → `scripts/agent/on_edit.dart`; allowlist for format/analyze/test/verify/`mason make bloc` and the `dart` MCP server; force-push denied. |
| `.claude/skills/flutter-senior-dev/` | Claude Code | Entry point that loads the shared skill below. |
| `.claude/agents/flutter-qa.md` | Claude Code | One-shot review subagent: runs the gate, then checks what tools can't. |
| `.agents/skills/flutter-senior-dev/` | Codex, Cursor, Gemini CLI, OpenCode, ... | Shared [Agent Skills](https://agentskills.io) skill: workflows, architecture snapshot, API/state/UI references, known gaps, planning checklist. |
| `.mcp.json`, `.cursor/mcp.json` | MCP clients | Registers `dart mcp-server` (ships with the Dart SDK): analyzer, LSP, pub.dev search, and hot reload / runtime errors / widget inspector on a running app. |
| `scripts/agent/verify.dart` (+ `.sh`/`.ps1`) | everyone, CI | Quality gate: format → analyze → custom lints → tests → snapshot. `--fast` for format + analyze. |
| `scripts/agent/on_edit.dart` | hook | Formats and analyzes the edited Dart file; reports issues back to the agent (exit 2). |
| `scripts/agent/wire_route.dart` | everyone | Scaffolds a feature with `mason make bloc` if missing and wires its route. Refuses to guess with `go_router` / `auto_route`. |
| `scripts/agent/snapshot.dart` | memory | Deterministic `.harness/system-snapshot.md`: features (and which lack tests), routes, endpoints, `AppState` fields, dependencies. |
| `scripts/agent/upgrade.dart` | maintainers | Upgrades the harness in place (below). |
| `.harness/` | memory | `active-context.md` (agent-maintained, capped), `progress.md` (append-only log), `version.json` (version, ids, upgrade history). |

---

## 🔄 Upgrading an Existing Project

```bash
mason upgrade -g                       # refresh the registered harness brick
dart run scripts/agent/upgrade.dart    # --check-only / --force
```

1. **Managed** — `scripts/agent/`, the skill and the QA subagent are replaced.
2. **Memory** — `.harness/active-context.md` and `progress.md` are never touched (one log line is added to Recent Tasks).
3. **Contracts** — `AGENTS.md` / `CLAUDE.md` get the new template above the `harness:project-rules` marker; everything below it is kept verbatim. Pre-1.6 files without the marker have their custom sections recovered and moved below it. Config you may have edited (`.claude/settings.json`, `.mcp.json`) is only added when missing.

Nothing changes if the brick fails to render, a backup of every touched file goes to `.harness/.backup_<timestamp>/` (last three kept), and the app ids come from `version.json` (or, for older projects, the old `CLAUDE.md` / platform files) — never a `com.example` guess. `--check-only` writes `has_update` / `new_version` to `$GITHUB_OUTPUT` for CI.

---

## ⚙️ Generation Architecture

`harness` v1.6.0 is a pure-template brick (zero hooks): everything renders
from `__brick__/`, so generation is instant and avoids the Windows `MAX_PATH`
issues that hook compilation caused in 1.3.x. Note that mason does not keep the
executable bit: run the wrapper as `bash scripts/agent/verify.sh`, or call
`dart run scripts/agent/verify.dart` directly.

See [`CHANGELOG.md`](https://github.com/jenilseawind-glitch/Flutter-RxDart-Base/blob/main/bricks/harness/CHANGELOG.md) for version history.
