# {{project_name}} — Claude Code memory

@AGENTS.md

## Claude Code specifics
- Android package `{{android_package_name}}`, iOS bundle id `{{ios_bundle_id}}`.
- Skills in `.claude/skills/` (listed in AGENTS.md §4) carry the procedures: `add-feature`, `add-endpoint`, `manage-state`, `build-ui`, `write-tests`, `fix-bug`, `evolve-harness`, and `flutter-senior-dev` for planning and review. Invoke the matching one before starting work.
- Close every task with the learning step in AGENTS.md §6: `dart run scripts/agent/learn.dart` is pre-approved.
- Subagent `flutter-qa` (`.claude/agents/flutter-qa.md`, configured with `haiku`) does a one-shot architecture review. Never auto-spawn; invoke only when explicitly asked.
- Context hygiene: Run `/clear` when switching tasks to keep sessions under 50k context. Run `/compact` mid-task after completing a layer (e.g. data + BLoC done, before UI). Grep or read line ranges rather than loading entire large files into context.
- The `dart` MCP server is pre-approved: use `mcp__dart__*` tools for analysis, symbol lookup, pub.dev search and the running app (hot reload, runtime errors, widget tree).
- In FVM projects (`.fvm/` or `.fvmrc`), prefix CLI commands with `fvm` (e.g. `fvm dart run scripts/agent/verify.dart`, `fvm flutter test`).

<!-- harness:project-rules — Everything below this line is yours. `upgrade.dart` keeps it verbatim. -->

---
@.harness/active-context.md
