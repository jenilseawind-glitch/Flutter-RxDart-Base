// ignore_for_file: avoid_print

import 'dart:io';

/// Fast (<1.5s) in-flight quality gate for recently modified Dart files.
///
/// Usage:
///   dart run scripts/agent/on_edit.dart [file1.dart file2.dart ...]
///
/// If no files are specified, runs against modified files from git status.
Future<void> main(List<String> args) async {
  final files = <String>{};

  if (args.isNotEmpty) {
    files.addAll(args.where((f) => f.endsWith('.dart') && File(f).existsSync()));
  } else {
    final status = Process.runSync('git', ['status', '--porcelain'], runInShell: true);
    if (status.exitCode == 0) {
      for (final line in (status.stdout as String).split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final path = parts.last;
          if (path.endsWith('.dart') && File(path).existsSync()) {
            files.add(path);
          }
        }
      }
    }
  }

  final targetFiles = files
      .where((f) => !f.endsWith('.g.dart') && !f.endsWith('.freezed.dart'))
      .toList();

  if (targetFiles.isEmpty) {
    print('on_edit: no modified Dart files to check.');
    return;
  }

  final fvm = Directory('.fvm').existsSync() || File('.fvmrc').existsSync();
  final cmd = fvm ? 'fvm' : 'dart';
  final prefix = fvm ? ['dart'] : <String>[];

  print('on_edit: checking ${targetFiles.length} file(s)...');

  // Format check
  final formatResult = await Process.run(
    cmd,
    [...prefix, 'format', '--set-exit-if-changed', ...targetFiles],
    runInShell: true,
  );
  if (formatResult.exitCode != 0) {
    stderr.write(formatResult.stderr);
    stderr.write(formatResult.stdout);
    print('on_edit: formatting failed. Run `dart format` to fix.');
    exit(formatResult.exitCode);
  }

  // Analyze check
  final analyzeResult = await Process.run(
    cmd,
    [...prefix, 'analyze', '--fatal-infos', ...targetFiles],
    runInShell: true,
  );
  if (analyzeResult.exitCode != 0) {
    stderr.write(analyzeResult.stderr);
    stderr.write(analyzeResult.stdout);
    print('on_edit: analysis failed.');
    exit(analyzeResult.exitCode);
  }

  print('on_edit: clean (format + analyze passed).');
}
