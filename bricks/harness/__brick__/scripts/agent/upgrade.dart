// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Upgrades the AI agent harness in this project without losing context.
///
///   dart run scripts/agent/upgrade.dart              # upgrade to the installed brick
///   dart run scripts/agent/upgrade.dart --check-only # compare with the latest upstream tag
///   dart run scripts/agent/upgrade.dart --force      # re-apply even if versions match
///
/// Three tiers:
/// 1. **Managed** (`scripts/agent/`, skills, the QA subagent) — replaced.
/// 2. **Memory** (`.harness/active-context.md`, `progress.md`) — never touched.
/// 3. **Contracts** (`AGENTS.md`, `CLAUDE.md`) — the template part above the
///    `harness:project-rules` marker is replaced; everything below it is kept
///    verbatim. Config files you may have edited (`.claude/settings.json`,
///    `.mcp.json`) are only added when missing.
///
/// The new templates come from the `harness` brick registered with mason
/// (`mason add -g harness --git-url <repo> --git-path bricks/harness`, then
/// `mason upgrade -g`). Nothing is changed unless rendering succeeds, and a
/// backup of every touched file is kept in `.harness/.backup_<timestamp>/`.
Future<void> main(List<String> args) async {
  final checkOnly = args.contains('--check-only');
  final force = args.contains('--force');

  if (!File('pubspec.yaml').existsSync()) {
    _fail('Run from the Flutter project root (pubspec.yaml not found).');
  }

  final manifestFile = File('.harness/version.json');
  final manifest = _readJson(manifestFile);
  final current = manifest['version']?.toString() ?? '0.0.0';
  // fork-url: the fork until upstream (TheJenilDGohel) merges harness 1.6.
  final upstream =
      manifest['upstream_repo']?.toString() ??
      'https://github.com/jenilseawind-glitch/Flutter-RxDart-Base.git';

  if (checkOnly) {
    final latest = await _latestUpstreamVersion(upstream);
    final hasUpdate = latest != null && _compare(latest, current) > 0;
    if (latest == null) {
      print(
        'Could not determine the latest harness version from $upstream '
        '(network or repository unavailable). Installed: $current.',
      );
    } else if (hasUpdate) {
      print('Update available: $current → $latest');
    } else {
      print('Harness $current is up to date (upstream: $latest).');
    }
    final ghOutput = Platform.environment['GITHUB_OUTPUT'];
    if (ghOutput != null) {
      File(ghOutput).writeAsStringSync(
        'has_update=$hasUpdate\nnew_version=${latest ?? current}\n',
        mode: FileMode.append,
      );
    }
    return;
  }

  final vars = _resolveVars(manifest);
  print(
    'Harness $current — rendering templates for ${vars['project_name']} '
    '(${vars['android_package_name']} / ${vars['ios_bundle_id']})...',
  );

  final staging = Directory('.harness/.staging_upgrade');
  if (staging.existsSync()) staging.deleteSync(recursive: true);
  staging.createSync(recursive: true);

  try {
    final render = await Process.run('mason', [
      'make',
      'harness',
      for (final e in vars.entries) ...['--${e.key}', e.value],
      '--on-conflict',
      'overwrite',
      '-o',
      staging.path,
    ], runInShell: true);
    final target = _readJson(
      File('${staging.path}/.harness/version.json'),
    )['version']?.toString();
    if (render.exitCode != 0 || target == null) {
      _fail(
        'Could not render the harness brick (nothing was changed).\n'
        '${render.stderr}\n'
        'Register it once with:\n'
        '  mason add -g harness --git-url $upstream --git-path bricks/harness\n'
        'and refresh it with `mason upgrade -g`.',
      );
    }

    // A brick registered with `mason add -g` is cached; it only moves
    // forward with `mason upgrade -g`. Warn when it lags upstream.
    final latest = await _latestUpstreamVersion(upstream);
    final staleCache = latest != null && _compare(latest, target) > 0;
    if (staleCache) {
      print(
        'Note: your registered harness brick renders $target, but upstream '
        'is at $latest. Run `mason upgrade -g` and re-run this script.',
      );
    }

    final cmp = _compare(target, current);
    if (cmp == 0 && !force) {
      print(
        'Already on $target — the version your registered `harness` brick '
        'renders.\n'
        'Expected a newer one? Refresh the brick with `mason upgrade -g` '
        '(or register it: mason add -g harness --git-url $upstream '
        '--git-path bricks/harness). Use --force to re-apply $target.',
      );
      return;
    }
    final backup = _backup();
    print('Backup: ${backup.path}');

    // Tier 1 — managed files.
    for (final dir in [
      'scripts/agent',
      '.agents/skills/flutter-senior-dev',
      '.claude/skills/flutter-senior-dev',
    ]) {
      _replaceDir(Directory('${staging.path}/$dir'), Directory(dir));
    }
    _copyFile(
      '${staging.path}/.claude/agents/flutter-qa.md',
      '.claude/agents/flutter-qa.md',
    );
    // Moved to .claude/agents/ in 1.6.0.
    final legacyQa = File('.agents/agents/flutter-qa.md');
    if (legacyQa.existsSync()) legacyQa.deleteSync();

    // Tier 2 — memory: create only when missing.
    for (final f in ['.harness/active-context.md', '.harness/progress.md']) {
      if (!File(f).existsSync()) _copyFile('${staging.path}/$f', f);
    }

    // Config you may have customised: add only when missing.
    for (final f in [
      '.claude/settings.json',
      '.mcp.json',
      '.cursor/mcp.json',
    ]) {
      if (File(f).existsSync()) {
        print(
          'Kept your $f (compare with the template in the brick if needed).',
        );
      } else {
        _copyFile('${staging.path}/$f', f);
      }
    }

    // Tier 3 — contracts.
    for (final f in ['AGENTS.md', 'CLAUDE.md']) {
      final template = File('${staging.path}/$f').readAsStringSync();
      final existing = File(f).existsSync() ? File(f).readAsStringSync() : null;
      File(f).writeAsStringSync(mergeContract(f, template, existing));
    }

    // Manifest.
    final history = [...(manifest['history'] as List? ?? const [])];
    history.add({
      'from': current,
      'to': target,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    final staged = _readJson(File('${staging.path}/.harness/version.json'));
    manifestFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        ...staged,
        'vars': vars,
        if (manifest['installed_at'] != null)
          'installed_at': manifest['installed_at'],
        'history': history,
      }),
    );

    _logTask(current, target);
    print('Upgraded harness $current → $target.');
    print('Run `dart run scripts/agent/verify.dart` to confirm.');
  } finally {
    if (staging.existsSync()) staging.deleteSync(recursive: true);
  }
}

const marker = '<!-- harness:project-rules';
const _transclusion = '@.harness/active-context.md';

/// Template head (up to and including the marker line) + the project's
/// own tail. Files from before 1.6.0 have no marker: their custom sections
/// are recovered heuristically and placed below the marker.
String mergeContract(String file, String template, String? existing) {
  final templateMarker = template.indexOf(marker);
  if (existing == null || templateMarker == -1) return template;
  final head = template.substring(
    0,
    template.indexOf('\n', templateMarker) + 1,
  );

  final existingMarker = existing.indexOf(marker);
  if (existingMarker != -1) {
    return head +
        existing.substring(existing.indexOf('\n', existingMarker) + 1);
  }

  final custom = file == 'CLAUDE.md'
      ? _legacyClaudeCustom(existing)
      : _legacyAgentsCustom(existing);
  final templateTail = template.substring(head.length);
  if (custom.isEmpty) return template;
  return '$head\n$custom\n$templateTail';
}

/// Pre-1.6 CLAUDE.md: `##` sections the harness never shipped, up to the
/// trailing `---` / transclusion (which the template re-adds exactly once).
String _legacyClaudeCustom(String text) {
  const shipped = [
    'Stack',
    'State Rule',
    'Folder Map',
    'Adding a Feature',
    'Hard Rules',
    'QA & Review',
  ];
  final out = <String>[];
  var keep = false;
  for (final line in text.split('\n')) {
    if (line.trim() == '---' || line.trim().startsWith('@')) break;
    if (line.startsWith('## ')) {
      keep = !shipped.any(line.contains);
    }
    if (keep) out.add(line);
  }
  return out.join('\n').trim();
}

/// Pre-1.6 AGENTS.md: sections after "## 7. Project Context" (numbered 8+
/// or unnumbered), which the harness never shipped.
String _legacyAgentsCustom(String text) {
  final start = text.indexOf('## 7. Project Context');
  if (start == -1) return '';
  final next = RegExp(r'^## ', multiLine: true)
      .allMatches(text, start + 1)
      .map((m) => m.start)
      .where((i) => i > start)
      .firstOrNull;
  return next == null
      ? ''
      : text.substring(next).replaceAll(_transclusion, '').trim();
}

Map<String, String> _resolveVars(Map<String, dynamic> manifest) {
  final fromManifest =
      (manifest['vars'] as Map?)?.cast<String, dynamic>() ?? {};
  final name =
      fromManifest['project_name']?.toString() ??
      RegExp(
        r'^name:\s*(\w+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())?.group(1) ??
      'app';

  String? android = fromManifest['android_package_name']?.toString();
  String? ios = fromManifest['ios_bundle_id']?.toString();

  // Pre-1.6 projects: recover ids from the old CLAUDE.md, then the platforms.
  final claude = File('CLAUDE.md');
  if ((android == null || ios == null) && claude.existsSync()) {
    final m = RegExp(r'Android package: `([^`]+)`\. iOS bundle id: `([^`]+)`')
        .firstMatch(claude.readAsStringSync());
    android ??= m?.group(1);
    ios ??= m?.group(2);
  }
  for (final gradle in [
    'android/app/build.gradle.kts',
    'android/app/build.gradle',
  ]) {
    if (android != null) break;
    final f = File(gradle);
    if (f.existsSync()) {
      android = RegExp(r'''applicationId\s*=?\s*["']([^"']+)["']''')
          .firstMatch(f.readAsStringSync())
          ?.group(1);
    }
  }
  final pbx = File('ios/Runner.xcodeproj/project.pbxproj');
  if (ios == null && pbx.existsSync()) {
    ios = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
        .allMatches(pbx.readAsStringSync())
        .map((m) => m.group(1)!)
        .where((id) => !id.endsWith('RunnerTests'))
        .firstOrNull;
  }

  return {
    'project_name': name,
    'android_package_name': android ?? 'com.example.$name',
    'ios_bundle_id': ios ?? android ?? 'com.example.$name',
  };
}

Directory _backup() {
  final dir = Directory(
    '.harness/.backup_${DateTime.now().toUtc().millisecondsSinceEpoch}',
  )..createSync(recursive: true);
  for (final path in [
    'AGENTS.md',
    'CLAUDE.md',
    '.mcp.json',
    '.cursor/mcp.json',
    '.harness/active-context.md',
    '.claude',
    '.agents',
    'scripts/agent',
  ]) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.file) {
      _copyFile(path, '${dir.path}/$path');
    } else if (type == FileSystemEntityType.directory) {
      _replaceDir(Directory(path), Directory('${dir.path}/$path'));
    }
  }
  // Keep the three most recent backups.
  final backups =
      Directory('.harness')
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.contains('.backup_'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
  for (final old in backups.skip(3)) {
    old.deleteSync(recursive: true);
  }
  return dir;
}

void _logTask(String from, String to) {
  final file = File('.harness/active-context.md');
  if (!file.existsSync()) return;
  final entry =
      '- chore(harness): upgraded $from → $to (file:.harness/version.json)';
  var text = file.readAsStringSync().replaceAll('\r\n', '\n');
  if (text.contains('_No tasks completed yet._')) {
    text = text.replaceFirst('_No tasks completed yet._', entry);
  } else {
    text = text.replaceFirst('## Recent Tasks\n', '## Recent Tasks\n$entry\n');
  }
  file.writeAsStringSync(text);
}

void _replaceDir(Directory from, Directory to) {
  if (!from.existsSync()) return;
  if (to.existsSync()) to.deleteSync(recursive: true);
  to.createSync(recursive: true);
  for (final entity in from.listSync(recursive: true)) {
    final rel = entity.path.substring(from.path.length + 1);
    if (entity is File) _copyFile(entity.path, '${to.path}/$rel');
  }
}

void _copyFile(String from, String to) {
  final src = File(from);
  if (!src.existsSync()) return;
  File(to).parent.createSync(recursive: true);
  src.copySync(to);
}

Map<String, dynamic> _readJson(File file) {
  if (!file.existsSync()) return {};
  try {
    return (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
  } catch (_) {
    return {};
  }
}

/// Latest harness version published upstream: the `version:` in
/// `bricks/harness/brick.yaml` on the default branch, falling back to the
/// highest `v1.2.3` / `harness-v1.2.3` tag. Null when neither is reachable.
Future<String?> _latestUpstreamVersion(String repo) async {
  final gh = RegExp(r'github\.com[/:]([^/]+)/([^/]+?)(?:\.git)?/?$')
      .firstMatch(repo);
  if (gh != null) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(
        Uri.parse(
          'https://raw.githubusercontent.com/${gh[1]}/${gh[2]}/HEAD/bricks/harness/brick.yaml',
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final version = RegExp(
          r'^version:\s*(\S+)',
          multiLine: true,
        ).firstMatch(body)?.group(1);
        if (version != null) return version;
      }
    } catch (_) {
      // Fall through to tags.
    } finally {
      client.close(force: true);
    }
  }

  try {
    final r = await Process.run('git', ['ls-remote', '--tags', repo]);
    if (r.exitCode != 0) return null;
    final versions =
        RegExp(
            r'refs/tags/(?:harness-)?v?(\d+\.\d+\.\d+)$',
            multiLine: true,
          ).allMatches(r.stdout as String).map((m) => m.group(1)!).toList()
          ..sort(_compare);
    return versions.isEmpty ? null : versions.last;
  } catch (_) {
    return null;
  }
}

int _compare(String a, String b) {
  List<int> parts(String v) => v
      .split(RegExp(r'[-+]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
