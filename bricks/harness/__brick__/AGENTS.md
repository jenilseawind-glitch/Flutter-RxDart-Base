# AI Agent Contract & Architecture Standards

Read by every coding agent (Claude Code, Codex, Cursor, Copilot, Gemini CLI, ...).
Rules marked 🔒 fail the quality gate when broken (`redux_rxdart_lints`).

## 1. Architecture: Hybrid Redux + RxDart + Dio
- **Redux (global)**: session data that must survive a restart — `authToken`, `userData`, `locale`. Nothing else.
- **RxDart BLoC (per screen)**: fetch state, forms, pagination, search, toggles.
- **Dio**: HTTP/2, fixed interceptor order — Connectivity → Auth → PlatformInjector → Retry → ErrorMapping. Never reorder.

## 2. Golden Rules
1. 🔒 **Repository is transport only**: call `ApiBaseHelper`, return the raw `Map<String, dynamic>`. Never `fromJson`/`fromMap` (calls or tear-offs) in `repo/` or `*_repo.dart`. **One BLoC, one repo**: a BLoC never holds two repos. Compose shared capabilities (e.g. dropdowns, tags, profile, logout) with `mixin <Capability>Mixin` (`with FooMixin`) — never `extends OtherFeatureRepo` (inheritance leaks unrelated/sensitive methods).
2. **BLoC owns logic and state**: await the repo, parse with `Model.fromJson`, emit `ApiResponse<T>`. Widgets show errors with `error.userFacingMessage(context)` (or let `AppResponseBuilder` do it). Never display `e.toString()`.
3. 🔒 **Zero `setState`** in feature widgets. Drive UI from streams (`AppResponseBuilder`, `StreamBuilder`). Only design-system primitives in `lib/utils/widgets/ui/` may hold purely visual state.
4. 🔒 **Zero RxDart outside BLoCs**: widgets never import `rxdart`; they consume plain `Stream<T>` / `ApiResponse<T>`.
5. **Rule of 2**: a widget used in ≥ 2 places moves to `lib/utils/widgets/ui/`. Reuse with parameters before duplicating.
6. **Presentation**: standard `Scaffold` by default; `AppScaffold` when the shared chrome is wanted.
7. **Forms**: the `StatefulWidget` owns and disposes `TextEditingController`s and passes values to BLoC methods (`_bloc.submit(email: _email.text)`). BLoC streams drive spinners and error banners.
8. **Fetch**: `Future<void> fetch({bool refresh = false})`; call `createNewToken()` first (a newer fetch cancels the older one); ignore `RequestCancelledException`; emit errors with `retry: fetch`. Live search: `PublishSubject<String>` + `.debounceTime(300ms).distinct()`.
9. **One-off UI events** (toast, navigation): a `PublishSubject` in the BLoC, subscribed in `initState()`, cancelled in `dispose()`.
10. **Redux bridge**: when a feature changes session data, the BLoC emits the new model and the UI dispatches to the store after it renders.
11. **Auth**: `AuthInterceptor` attaches the bearer token only to the `BASE_URL` host. A 401 with a token dispatches `LogoutAction` automatically — don't add per-screen 401 handling.
12. **Defensive JSON parsing**: `(json['id'] as num?)?.toInt() ?? 0`, `json['name']?.toString() ?? ''`, `(json['items'] as List? ?? []).map(...)`, `DateTime.tryParse(json['at']?.toString() ?? '')`.
13. 🔒 **ScreenUtil only in public widgets**: `.w/.h/.r/.sp` inside a private (`_Foo`) widget is not rebuilt on resize. Make the widget public.

## 3. Before Writing Network Code
Look for `*.postman_collection.json`, then OpenAPI/Swagger, then docs. Add endpoints to `lib/networking/api_constants.dart`. Never guess a response shape — ask if no contract exists.

## 4. Tooling for Agents
- **Skills** (`.agents/skills/`; Claude Code: `.claude/skills/`). Load the one that fits before starting: `add-feature` (new screen/flow), `add-endpoint` (API work), `manage-state` (BLoC recipes, Redux changes), `build-ui`, `write-tests`, `fix-bug` (bugs, red gate), `evolve-harness` (lessons, rules, new skills), `flutter-senior-dev` (planning, architecture, review).
- **Scaffold + route in one step**: `dart run scripts/agent/wire_route.dart <feature_name> [route_path]` (runs `mason make bloc` if the feature is missing).
- **Quality gate** (must pass before proposing a commit): `dart run scripts/agent/verify.dart` — format, analyze, custom lints, tests, lessons, snapshot. `--fast` = format + analyze only. Wrappers: `bash scripts/agent/verify.sh`, `powershell -File scripts/agent/verify.ps1`.
- **Dart & Flutter MCP server** (`.mcp.json` → `dart mcp-server`, ships with the SDK): `analyze_files`, `lsp` (hover, definitions), `pub` / `pub_dev_search` (dependencies), `read_package_uris`, and against a running debug app `hot_reload`, `hot_restart`, `get_runtime_errors`, `widget_inspector`, `flutter_driver_command`. Prefer these over guessing APIs or reading pub-cache sources. Formatting and tests go through `verify.dart`.
- **Edit hook** (Claude Code): every edited Dart file is formatted and analyzed immediately; fix reported issues before moving on.
- **Learning loop**: `dart run scripts/agent/learn.dart list|add|hit|review|promote` over `.harness/lessons.md` (see §6).
- **Harness upgrade**: `dart run scripts/agent/upgrade.dart` (keeps `.harness/`, your own skills and everything below the project-rules marker).
- **FVM projects**: when `.fvm/` or `.fvmrc` exists, prefix bare CLI commands with `fvm` (e.g. `fvm dart run scripts/agent/verify.dart`, `fvm flutter test`). Agent scripts (`verify.dart`, `wire_route.dart`, `on_edit.dart`) detect FVM automatically.

## 5. Git
- Never commit or push unless asked. Run the quality gate first.
- Conventional Commits: `feat(<feature>): ...`, `fix(...)`, `refactor(...)`, `chore(...)`.

## 6. Project Memory & Learning (`.harness/`)
- **Start of task**: `.harness/active-context.md` is already in context for Claude Code; other agents read it first. Read `.harness/system-snapshot.md` for the project map (features, routes, endpoints, state, deps). Then load what the project learned for this task: `.harness/skills/<skill>.md` if it exists, and `dart run scripts/agent/learn.dart list <skill>`.
- **End of task (close-out)**: gate green, then update `active-context.md`:
  - `Current Focus`: 2-3 lines — what finished, what's next.
  - `Recent Tasks`: newest first, 1-2 lines each with proof (`commit:a1b2c3d` or `file:lib/...`). Max 5; move the oldest to `progress.md` as one line `[YYYY-MM-DD] type(scope): what (proof)`.
  - `Key Decisions`: 1-2 lines, decision + reason.
  - `Known Issues`: only what is still broken. Delete fixed items. `⏸ deferred by decision: <reason>` for items the owner chose to skip.
- **Lessons**: when a future agent would repeat something (a gate needed several attempts, the user corrected you, a backend quirk, a wrong or missing skill step), record one line: `learn.dart hit L<id>` if it's listed, else `learn.dart add <skill|general> "<trigger>: <fix>" --proof <ref>`. When `verify` reports lessons ready to promote, follow the `evolve-harness` skill. "Remember this" / "always X" from the user goes straight into §7 or the skill's overlay.
- Project knowledge lives only in `.harness/` and below the project-rules marker. The shipped skills, `scripts/agent/` and the text above the marker are replaced on upgrade.
- Never edit `system-snapshot.md` (generated by `verify`). Read `progress.md` only when asked for history.

<!-- harness:project-rules — Everything below this line is yours. `upgrade.dart` keeps it verbatim. -->
## 7. Project-Specific Rules
_Add team conventions, backend quirks, decisions and project skills that every agent must follow (promoted lessons land here)._
