# {{project_name}} — Claude Code memory

@AGENTS.md

## Claude Code specifics
- Android package `{{android_package_name}}`, iOS bundle id `{{ios_bundle_id}}`.
- Skill `flutter-senior-dev` (`.claude/skills/`) covers planning, scaffolding and review on this stack — use it for any feature or architecture work.
- Subagent `flutter-qa` (`.claude/agents/flutter-qa.md`) does a one-shot architecture review of a finished feature. Invoke it only when a review is asked for.
- The `dart` MCP server is pre-approved: use `mcp__dart__*` tools for analysis, symbol lookup, pub.dev search and the running app (hot reload, runtime errors, widget tree).
- A `PostToolUse` hook formats and analyzes each Dart file you edit; exit code 2 means fix the reported issues now.

<!-- harness:project-rules — Everything below this line is yours. `upgrade.dart` keeps it verbatim. -->

---
@.harness/active-context.md
