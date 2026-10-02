// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Claude Code `PostToolUse` hook (wired in `.claude/settings.json`).
///
/// After an agent edits a Dart file under `lib/` or `test/`, this formats
/// it and analyzes it. Analyzer findings are written to stderr with exit
/// code 2, which Claude Code feeds straight back to the agent — so mistakes
/// are fixed in the same turn instead of surfacing at the end in `verify`.
///
/// Any other tool, file type or malformed input is a silent no-op (exit 0):
/// a hook must never block unrelated work.
Future<void> main() async {
  final String path;
  try {
    final input = jsonDecode(await stdin.transform(utf8.decoder).join());
    final toolInput = (input as Map)['tool_input'] as Map?;
    path = (toolInput?['file_path'] ?? toolInput?['path'] ?? '') as String;
  } catch (_) {
    return;
  }

  final normalized = path.replaceAll('\\', '/');
  final inScope =
      normalized.contains('/lib/') ||
      normalized.contains('/test/') ||
      normalized.startsWith('lib/') ||
      normalized.startsWith('test/');
  if (!normalized.endsWith('.dart') || !inScope || !File(path).existsSync()) {
    return;
  }

  await Process.run('dart', ['format', path], runInShell: true);

  final analyze = await Process.run('dart', [
    'analyze',
    '--fatal-infos',
    path,
  ], runInShell: true);
  if (analyze.exitCode != 0) {
    stderr
      ..writeln(
        'dart analyze reported issues in $path — fix before continuing:',
      )
      ..write(analyze.stdout)
      ..write(analyze.stderr);
    exit(2);
  }
}
