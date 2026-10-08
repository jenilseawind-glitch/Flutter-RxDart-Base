# Flutter RxDart Base

Generate a Flutter app with one fixed architecture (Redux for the session, one RxDart BLoC per screen, Dio for networking), lint rules that enforce it, and an AI agent harness that teaches coding agents to follow it.

[![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-02569B?logo=flutter)](https://flutter.dev)
[![Mason](https://img.shields.io/badge/Mason-bricks-blue)](https://pub.dev/packages/mason_cli)
[![Lints](https://img.shields.io/badge/architecture-analyzer_enforced-green)](packages/redux_rxdart_lints.md)

---

## Quick start

```bash
# 1. Install the bricks (once per machine)
#    fork-url: the fork until upstream (TheJenilDGohel) merges the 1.6+ work.
mason add -g project --git-url https://github.com/jenilseawind-glitch/Flutter-RxDart-Base.git --git-path bricks/project
mason add -g bloc    --git-url https://github.com/jenilseawind-glitch/Flutter-RxDart-Base.git --git-path bricks/bloc
mason add -g harness --git-url https://github.com/jenilseawind-glitch/Flutter-RxDart-Base.git --git-path bricks/harness

# 2. Create an app and apply the architecture
flutter create my_app && cd my_app
mason make project      # asks for the project name, app ids, harness (Y) and secure storage (N)

# 3. Add a screen: scaffolds the feature and wires its route
dart run scripts/agent/wire_route.dart profile

# 4. Check everything: format, analyze, architecture lints, tests
dart run scripts/agent/verify.dart
```

`flutter run` works straight away and opens a showcase screen. Without the harness, use `mason make bloc` and add the route by hand.

---

## What's in the box

| | Version | How you use it | What it gives you |
|---|---|---|---|
| [`project`](bricks/project.md) | `1.5.0` | `mason make project`, once | Redux session store, Dio client with 5 interceptors, typed errors, router, design tokens, UI kit, l10n (en, hi), showcase screen |
| [`bloc`](bricks/bloc.md) | `1.2.1` | `mason make bloc`, once per screen | BLoC, repo, model, page, content widget and 7 passing BLoC tests |
| [`harness`](bricks/harness.md) | `1.8.0` | installed by `project` | `AGENTS.md`, eight agent skills, the quality gate, a lessons loop, a safe upgrade tool |
| [`redux_rxdart_lints`](packages/redux_rxdart_lints.md) | `0.4.0` | wired in by `project` | Turns five golden rules into analyzer errors |

---

## The architecture in one minute

- **Redux holds only the session**: auth token, user data, locale. It's persisted and survives restarts. Nothing else goes there.
- **Each screen has one RxDart BLoC** for everything it shows: fetching, forms, search, paging. The page creates it and disposes it.
- **Dio does the networking** behind `ApiBaseHelper`, through a fixed chain: connectivity → auth → platform → retry → error mapping. Every failure is a typed `ApiException`, and screens receive a sealed `ApiResponse<T>` (initial, loading, success, or error with retry).

```
Page ──stream──▶ BLoC ──await──▶ Repo ──▶ ApiBaseHelper ──▶ Dio + interceptors
                 parses JSON     returns the raw Map
Page dispatches to Redux only when the session changes (sign-in, profile, logout)
```

A feature is one folder:

```
lib/features/profile/
├── bloc/profile_bloc.dart              # state and logic; public streams end in $
├── repo/profile_repo.dart              # HTTP only, returns the raw Map
├── model/profile_model.dart            # defensive fromJson
├── widgets/profile_content_widget.dart # draws the parsed model
└── profile_page.dart                   # owns the BLoC, renders with AppResponseBuilder
```

The architecture lints (in the IDE and in `verify.dart`) reject parsing in repos, `setState` in feature widgets, RxDart in widgets, and ScreenUtil sizes in private widgets. All 13 golden rules are in the generated `AGENTS.md`, and the design is explained in [Architecture](architecture.md).

---

## Working with AI agents

With the harness, an agent working in your app:

1. **Reads the rules** from `AGENTS.md` (Claude Code through `CLAUDE.md`).
2. **Picks a skill for the job**: `add-feature`, `add-endpoint`, `manage-state`, `build-ui`, `write-tests`, `fix-bug`, `evolve-harness`, or `flutter-senior-dev` for planning and review.
3. **Gets feedback while it works**: an edit hook in Claude Code and the Dart MCP server. It must pass `verify.dart` before calling the work done.
4. **Records lessons** with `learn.dart`, so the next session doesn't repeat a mistake. A lesson seen twice becomes a project rule or skill step.

Try: *"Add a profile screen for `GET /me`; the Postman collection is in `docs/`."* More in [the harness docs](bricks/harness.md).

---

## Upgrading the harness in an app

```bash
dart run scripts/agent/upgrade.dart
```

It renders the latest release, updates only harness files, and keeps your memory, lessons, own scripts and project rules. On 1.7.0 or older, install the new `upgrade.dart` first; see [Upgrading from 1.7.0 or older](bricks/harness.md#upgrading-from-170-or-older).

---

## Documentation

- [Architecture](architecture.md): layers, the state rule, networking, trade-offs
- Bricks: [`project`](bricks/project.md) · [`bloc`](bricks/bloc.md) · [`harness`](bricks/harness.md) · lints: [`redux_rxdart_lints`](packages/redux_rxdart_lints.md)
- [AI harness research](ai-harness-rnd.md): why the harness works the way it does
- [Roadmap](roadmap.md) · [Contributing](contributing.md)

## Contributing

Every template change bumps its brick's version and CHANGELOG, and CI generates a real app to test it: see [Contributing](contributing.md). AI agents working on this repository should use the `base-maintainer` skill in `.agents/skills/base-maintainer/`.

Released under the [MIT License](https://github.com/jenilseawind-glitch/Flutter-RxDart-Base/blob/main/LICENSE).
