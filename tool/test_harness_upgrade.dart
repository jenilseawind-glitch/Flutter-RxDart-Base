import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// End-to-end test of the harness's real `scripts/agent/upgrade.dart`
/// against a pre-1.6 project carrying team customisations.
///
/// Run from the repository root: `dart run tool/test_harness_upgrade.dart`.
/// Mason resolves `harness` from this repo's mason.yaml, so the upgrade
/// renders the working-tree brick.
Future<void> main() async {
  final root = Directory.current.path;
  final app = Directory(p.join(root, 'temp_upgrade_test'));
  if (app.existsSync()) app.deleteSync(recursive: true);
  app.createSync(recursive: true);

  final failures = <String>[];
  void check(String name, bool ok) {
    print('${ok ? 'PASS' : 'FAIL'}  $name');
    if (!ok) failures.add(name);
  }

  String read(String rel) => File(p.join(app.path, rel)).readAsStringSync();
  bool exists(String rel) => File(p.join(app.path, rel)).existsSync();
  void write(String rel, String content) => File(p.join(app.path, rel))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
  int count(String haystack, String needle) =>
      needle.allMatches(haystack).length;

  try {
    // ── A legacy (1.5.x) project with team customisations ──────────────
    write('pubspec.yaml', 'name: legacy_app\nenvironment:\n  sdk: ^3.13.0\n');
    write(
        'scripts/agent/upgrade.dart',
        File(p.join(
          root,
          'bricks/harness/__brick__/scripts/agent/upgrade.dart',
        )).readAsStringSync());
    write(
        '.harness/version.json',
        jsonEncode({
          'brick': 'harness',
          'version': '1.5.0',
          'installed_at': '2026-01-01T00:00:00Z',
        }));
    const memory = '''# Active Context

## Current Focus
Migrating checkout to Stripe PaymentSheet.

## Recent Tasks
- feat(payment): scaffold payment_bloc (commit:a1b2c3d)

## Key Decisions
- PaymentIntents API, not Charges.

## Known Issues
- 3DS takes 4s on the Android emulator.
''';
    write('.harness/active-context.md', memory);
    write('.harness/progress.md', '# Progress Log\n[2026-01-01] chore: init\n');
    write('CLAUDE.md', '''# legacy_app — Project Memory

## Stack
Flutter · Redux · RxDart · Dio.
Android package: `com.acme.legacy`. iOS bundle id: `com.acme.legacy-ios`.

## Hard Rules
- old rule text

## Team Notes
Always talk to the payments team before touching checkout.

---
@.harness/active-context.md
''');
    write('AGENTS.md', '''# AI Agent Contract & Architecture Standards

## 2. Inviolable Golden Rules
1. old rules

## 7. Project Context (.harness/)
- old context rules

## 8. Payments
Never log card numbers.
''');
    write('.agents/agents/flutter-qa.md', 'legacy qa agent');
    write('.agents/skills/team-payments/SKILL.md',
        '---\nname: team-payments\ndescription: ours\n---\n');

    // ── Upgrade ─────────────────────────────────────────────────────────
    var run = await Process.run('dart', ['run', 'scripts/agent/upgrade.dart'],
        workingDirectory: app.path, runInShell: true);
    print(run.stdout);
    if (run.exitCode != 0) print(run.stderr);
    check('upgrade exits 0', run.exitCode == 0);

    final brickVersion = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(
            File(p.join(root, 'bricks/harness/brick.yaml')).readAsStringSync())!
        .group(1);
    final manifest = jsonDecode(read('.harness/version.json')) as Map;
    check('manifest stamped with brick version $brickVersion',
        manifest['version'] == brickVersion);
    check('manifest keeps installed_at',
        manifest['installed_at'] == '2026-01-01T00:00:00Z');
    check(
        'manifest records history', (manifest['history'] as List).length == 1);
    check('android id recovered from legacy CLAUDE.md',
        (manifest['vars'] as Map)['android_package_name'] == 'com.acme.legacy');

    final claude = read('CLAUDE.md');
    check('CLAUDE.md imports AGENTS.md', claude.contains('@AGENTS.md'));
    check('CLAUDE.md keeps real ids', claude.contains('com.acme.legacy-ios'));
    check(
        'CLAUDE.md keeps team notes once', count(claude, '## Team Notes') == 1);
    check('CLAUDE.md drops shipped legacy sections',
        !claude.contains('old rule text'));
    check('CLAUDE.md transcludes memory exactly once',
        count(claude, '@.harness/active-context.md') == 1);

    final agents = read('AGENTS.md');
    check('AGENTS.md has new template',
        agents.contains('## 4. Tooling for Agents'));
    check('AGENTS.md keeps custom section once',
        count(agents, '## 8. Payments') == 1);
    check('AGENTS.md has project-rules marker',
        agents.contains('harness:project-rules'));

    final context = read('.harness/active-context.md');
    check(
        'memory preserved',
        context.contains('Stripe PaymentSheet') &&
            context.contains('3DS takes 4s'));
    check('upgrade logged in Recent Tasks',
        context.contains('chore(harness): upgraded 1.5.0'));
    check('progress log untouched',
        read('.harness/progress.md').contains('[2026-01-01] chore: init'));

    check(
        'QA subagent moved to .claude/agents',
        exists('.claude/agents/flutter-qa.md') &&
            !exists('.agents/agents/flutter-qa.md'));
    check(
        'Claude skill + settings + MCP config added',
        exists('.claude/skills/flutter-senior-dev/SKILL.md') &&
            exists('.claude/settings.json') &&
            exists('.mcp.json'));

    final shipped = Directory(
      p.join(root, 'bricks/harness/__brick__/.agents/skills'),
    ).listSync().whereType<Directory>().map((d) => p.basename(d.path)).toList()
      ..sort();
    check(
        'every shipped skill installed for all agents and Claude Code',
        shipped.length >= 8 &&
            shipped.every((s) =>
                exists('.agents/skills/$s/SKILL.md') &&
                exists('.claude/skills/$s/SKILL.md')));
    check('manifest records managed_skills',
        (manifest['managed_skills'] as List).join(',') == shipped.join(','));
    check('project-created skill untouched',
        read('.agents/skills/team-payments/SKILL.md').contains('ours'));
    check('lessons store created for old projects',
        read('.harness/lessons.md').contains('## Active'));
    check('learn.dart installed', exists('scripts/agent/learn.dart'));
    final backups = Directory(p.join(app.path, '.harness'))
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.contains('.backup_'));
    check(
        'backup holds the old CLAUDE.md',
        backups.any((d) => File(p.join(d.path, 'CLAUDE.md'))
            .readAsStringSync()
            .contains('Project Memory')));

    // ── Idempotency ─────────────────────────────────────────────────────
    write(
        'CLAUDE.md', '${read('CLAUDE.md')}\n## Added After Upgrade\nkeep me\n');
    run = await Process.run('dart', ['run', 'scripts/agent/upgrade.dart'],
        workingDirectory: app.path, runInShell: true);
    check('second run is a no-op',
        run.exitCode == 0 && (run.stdout as String).contains('Already on'));
    check('no-op run points at a stale mason cache',
        (run.stdout as String).contains('mason upgrade -g'));

    // --check-only must never claim "up to date" when it couldn't look.
    final manifestPath = p.join(app.path, '.harness', 'version.json');
    final realManifest = File(manifestPath).readAsStringSync();
    final offline = (jsonDecode(realManifest) as Map)
      ..['upstream_repo'] = 'https://github.com/nobody-xyz-404/missing.git';
    File(manifestPath).writeAsStringSync(jsonEncode(offline));
    run = await Process.run(
        'dart', ['run', 'scripts/agent/upgrade.dart', '--check-only'],
        workingDirectory: app.path, runInShell: true);
    final checkOut = run.stdout as String;
    check(
        '--check-only reports an unreachable upstream honestly',
        checkOut.contains('Could not determine') &&
            !checkOut.contains('up to date'));
    File(manifestPath).writeAsStringSync(realManifest);

    // Project knowledge, a skill the harness stopped shipping, and an
    // older settings.json, before re-applying.
    const learned = '# Lessons\n\n## Active\n'
        '- [L1] add-endpoint (2x, 2026-10-01): Dates are epoch seconds.\n'
        '\n## Promoted\n_None yet._\n';
    write('.harness/lessons.md', learned);
    write('.harness/skills/add-feature.md', '# add-feature additions\n');
    write('.agents/skills/retired-skill/SKILL.md', 'old');
    write('.claude/skills/retired-skill/SKILL.md', 'old');
    final stamped = jsonDecode(File(manifestPath).readAsStringSync()) as Map;
    stamped['managed_skills'] = [
      ...stamped['managed_skills'] as List,
      'retired-skill'
    ];
    File(manifestPath).writeAsStringSync(jsonEncode(stamped));
    write('.claude/settings.json',
        '{"permissions": {"allow": ["Bash(flutter test:*)"]}}');

    run = await Process.run(
        'dart', ['run', 'scripts/agent/upgrade.dart', '--force'],
        workingDirectory: app.path, runInShell: true);
    check('lessons kept verbatim', read('.harness/lessons.md') == learned);
    check('skill overlay kept',
        read('.harness/skills/add-feature.md') == '# add-feature additions\n');
    check(
        'a skill the harness no longer ships is removed',
        !exists('.agents/skills/retired-skill/SKILL.md') &&
            !exists('.claude/skills/retired-skill/SKILL.md') &&
            exists('.agents/skills/team-payments/SKILL.md'));
    check(
        'missing template permissions are listed, settings kept',
        (run.stdout as String).contains('learn.dart') &&
            read('.claude/settings.json').contains('flutter test'));
    final forced = read('CLAUDE.md');
    check('--force keeps everything below the marker',
        forced.contains('keep me') && count(forced, '## Team Notes') == 1);
    check('--force does not duplicate the transclusion',
        count(forced, '@.harness/active-context.md') == 1);
    check('--force keeps AGENTS.md custom section once',
        count(read('AGENTS.md'), '## 8. Payments') == 1);
  } finally {
    if (app.existsSync()) app.deleteSync(recursive: true);
  }

  if (failures.isEmpty) {
    print('\nAll harness upgrade checks passed.');
  } else {
    stderr.writeln('\n${failures.length} check(s) failed.');
    exitCode = 1;
  }
}
