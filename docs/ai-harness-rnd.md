# AI Harness R&D (October 2026)

**Question:** the AI layer felt like the weakest part of the bricks. What is actually wrong with it, what do current tools support, and what should we build?

**Short answer:** the harness's *content* was decent, but its *wiring* was weak. The main target, Claude Code, never loaded most of it. It also relied on agents remembering rules instead of running tools. Harness **1.6.0** fixes the wiring and adds feedback loops. The biggest remaining gap is that we cannot yet *measure* whether the harness makes agents better, so an eval suite is the top roadmap item.

## How this was evaluated

- Read every harness file, then generated a real app (Flutter 3.47.6 / Dart 3.13.5) with `project` + `harness` + `bloc` and exercised each piece.
- Checked current agent-tool conventions: [AGENTS.md](https://www.morphllm.com/agents-md-guide) (Linux Foundation / Agentic AI Foundation, read natively by Codex, Copilot, Cursor, Gemini CLI, and by Claude Code [when no CLAUDE.md exists](https://www.highcircl.com/en/blog/claude-code-agents-md-support)), the [Agent Skills standard](https://codex.danielvaughan.com/2026/05/05/agent-skills-open-standard-portable-skills-codex-cli-cross-agent/) (`SKILL.md`; `.agents/skills/` for Codex/OpenCode, `.claude/skills/` for Claude Code, [Cursor reads both](https://cursor.com/docs/skills)), Claude Code [subagent discovery](https://code.claude.com/docs/en/sub-agents) (`.claude/agents/`), the [official Dart & Flutter MCP server](https://docs.flutter.dev/ai/tools), Flutter's [AI rules](https://docs.flutter.dev/ai/ai-rules), and the first-party [analyzer plugin system](https://dart.dev/tools/analyzer-plugins).
- Probed `dart mcp-server` over stdio, and ran the hook, gate, snapshot and upgrade against real files.

## Findings (before 1.6.0), most severe first

| # | Problem | Evidence | Effect on agents |
|---|---|---|---|
| 1 | **Claude Code never saw the golden rules** | `CLAUDE.md` said "the full contract lives in `AGENTS.md`" but did not import it. Claude Code only falls back to `AGENTS.md` when there is *no* `CLAUDE.md`. | The 12 rules were in context only if the model chose to open another file. |
| 2 | **Skill and QA agent were in folders Claude Code doesn't scan** | Claude Code discovers `.claude/skills/` and `.claude/agents/`; the harness shipped `.agents/skills/` and `.agents/agents/`. | The senior-dev skill and `flutter-qa` were never auto-offered. |
| 3 | **No machine feedback while editing** | Everything depended on the agent remembering to run `verify` at the end. | Errors piled up across files before anyone saw them. |
| 4 | **Agents couldn't use Dart tooling directly** | No MCP config, although the SDK ships `dart mcp-server`. | Agents guessed APIs and shelled out, with no runtime view of the app. |
| 5 | **The gate didn't run tests**; a fresh app failed its own format gate | `verify.sh` was format + analyze + lints + snapshot. 26 generated files were unformatted under the Dart 3.13 formatter. | "All gates passed" did not mean the code worked. Day-one agents hit a red gate they did not cause. |
| 6 | **Reference docs were stale and contradicted the code** | `architecture.md` described harness 1.1.0 (OverlaySupport, `screens/`, 8 exceptions, empty `model/`). The skill sent shared widgets to `utils/widgets/common/` (doesn't exist). Rule 11 described token behaviour that is now wrong. | Confidently wrong code. This is the worst failure mode, because agents trust these files. |
| 7 | **`upgrade.dart` could silently damage projects** | It stamped success when `mason make` failed, overwrote app ids with `com.example.<name>`, duplicated the memory transclusion on every run, and its test exercised a *different copy* of the engine. | Upgrades were unsafe to run unattended. |
| 8 | **Snapshot was noisy** | A timestamp and git log changed it on every run, and it ran a second full analyzer pass. | Committing it produced diff noise; leaving it out lost it. |

## What 1.6.0 changes

| Problem | Change | Verified by |
|---|---|---|
| 1 | `CLAUDE.md` = `@AGENTS.md` + Claude-specific notes + memory transclusion | Generated file inspected |
| 2 | `.claude/skills/flutter-senior-dev/` entry point → shared skill; `flutter-qa` moved to `.claude/agents/` | Upgrade test asserts the move |
| 3 | `PostToolUse` hook → `scripts/agent/on_edit.dart`: formats and analyzes each edited Dart file and returns issues with exit 2 | Clean file → 0; broken file → formatted, diagnostics, 2; non-Dart and garbage input → 0 |
| 4 | `.mcp.json` / `.cursor/mcp.json` register `dart mcp-server`, and it is pre-approved in Claude Code | Server v1.1.2 handshake: 14 tools (`analyze_files`, `lsp`, `pub`, `pub_dev_search`, `read_package_uris`, `hot_reload`, `hot_restart`, `get_runtime_errors`, `widget_inspector`, `flutter_driver_command`, …) |
| 5 | `verify.dart`: format → analyze → custom lints → **tests** → snapshot (`--fast` mode). `project` and `bloc` hooks format their output. | Generated app: 5/5 gates pass. The base repo's smoke test now uses the strict format check. |
| 6 | Content rewritten against the generated code, and the skill points at `AGENTS.md` instead of restating rules. **New `tool/harness_check.dart` in CI** fails when harness docs name a path, project type or lint rule the bricks don't generate. | Catches an invented `AppStreamView`; passes on the real docs |
| 7 | `upgrade.dart` rewritten: no change unless rendering succeeds, ids kept in `version.json`, `harness:project-rules` marker merge, legacy migration, backups, history, `$GITHUB_OUTPUT` | `tool/test_harness_upgrade.dart`: 23/23 checks on the real script, including idempotent re-runs |
| 8 | Deterministic snapshot (features without tests, routes, endpoints, state fields, deps), with no analyzer re-run | Second run reports "unchanged" |

Also new: golden rule 13 (lint-enforced), a permission allowlist for safe dev commands, a deny-list for force-push and signing keys, and `bash scripts/agent/verify.sh` (mason drops the executable bit).

**Measured gate cost on a fresh app:** format 0.3 s, analyze 4.2 s, custom_lint **40.1 s**, tests 13.8 s, snapshot 0.4 s. custom_lint takes about two-thirds of the gate, and it is why the edit hook can only run the analyzer.

## Roadmap (not built yet), in priority order

1. **Agent eval suite (do this next).** Without it, every harness change is a guess.
   - Keep 10–20 realistic tasks (for example "add a profile screen for `GET /me` from this Postman file", "add pull-to-refresh pagination", "fix this 401 loop").
   - Run each task headless (`claude -p`, `codex exec`) in a fresh generated app.
   - Score each run with signals we already have: `verify.dart` passes, zero lint findings, the generated BLoC tests still pass, plus a rubric review by `flutter-qa`.
   - Track pass rate and cost per harness version in CI on a schedule (each run costs API tokens).
2. **Move `redux_rxdart_lints` to the first-party analyzer plugin API** (`analysis_server_plugin`, Dart ≥ 3.10).
   - The rules would run inside `dart analyze` / `flutter analyze`, so the edit hook, the MCP `analyze_files` tool and every IDE enforce them instantly. That replaces the 40 s custom_lint step.
   - Watch the open [performance issue](https://github.com/dart-lang/sdk/issues/63292) and measure before switching.
   - [Migration guide](https://leancode.co/blog/migrating-to-dart-analyzer-plugin-system).
3. **More lint rules for what is mechanical.** These are the strongest kind of guardrail, because the agent cannot forget them:
   - `fetch` must call `createNewToken()` first.
   - No `e.toString()` / `$e` in widget text.
   - No `withOpacity`.
   - No string literals in `Text(...)` inside `lib/features/` (l10n).
   - BLoC subjects must be closed in `dispose()`.
4. **Spec-first feature workflow.**
   - A `new-feature` skill: collect the API contract → write `.harness/specs/<feature>.md` with acceptance criteria → `wire_route.dart` → implement → turn each criterion into a BLoC test → `verify`.
   - Pair it with contract ingestion: OpenAPI/Postman → repo method, model `fromJson` and JSON fixtures for tests. This targets agents' most common failure, which is inventing response shapes.
5. **Opt-in `Stop` hook** that runs `verify.dart --fast` before the agent reports "done", so a red gate cannot be handed back. It is opt-in because it adds about 5 s to every finished turn.
6. **Runtime loop.** Document a debug-run workflow (`flutter run` + MCP `hot_reload` / `get_runtime_errors` / `widget_inspector`). Add golden/screenshot tests, so agents get a visual signal for UI work instead of none.
7. **Memory hygiene.**
   - Auto-append `progress.md` from commit messages (a git hook), so agents spend fewer tokens maintaining logs.
   - Flag `active-context.md` entries that are older than N commits as possibly stale.
8. **More tools.** Add `.vscode/mcp.json` and `.gemini/settings.json` only if the team uses those tools. Copilot and Gemini CLI already read `AGENTS.md`.

## What we deliberately did not do

- **No hooks in the harness brick.** It stays a pure template because hook compilation caused the Windows `MAX_PATH` failures fixed in 1.4.x. Everything new is plain files.
- **No `.cursor/rules/*.mdc` or Copilot instruction duplicates.** Those tools read `AGENTS.md`, and every extra copy is another place for rules to drift.
- **No custom_lint in the edit hook.** At 40 s per edit it would make agents slower without making them better.
