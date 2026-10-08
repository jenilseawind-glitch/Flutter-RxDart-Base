// ignore_for_file: avoid_print

import 'dart:io';

/// The project's quality gate. Cross-platform; `verify.sh` / `verify.ps1`
/// are thin wrappers around it.
///
///   dart run scripts/agent/verify.dart            # full gate
///   dart run scripts/agent/verify.dart --fast     # format + analyze only
///   dart run scripts/agent/verify.dart --no-snapshot
///
/// Steps stop at the first failure and print the failing tool's output,
/// so an agent can act on it directly. The lessons step also prints its
/// summary on success: lessons ready to promote are the next agent's cue
/// (see the `evolve-harness` skill).
///
/// FVM: when `.fvm/` or `.fvmrc` exists, all subprocess calls use
/// `fvm dart` / `fvm flutter` instead of bare `dart` / `flutter`.
Future<void> main(List<String> args) async {
  final fast = args.contains('--fast');
  final snapshot = !args.contains('--no-snapshot') && !fast;
  final fvm = _useFvm();
  if (fvm) print('FVM detected — using `fvm dart` / `fvm flutter`.\n');

  final sources = ['lib', 'test'].where((d) => Directory(d).existsSync());
  final steps = <_Step>[
    _Step('Formatting', 'dart', [
      'format',
      '--set-exit-if-changed',
      ...sources,
    ]),
    // Also runs the redux_rxdart_lints analyzer plugin (analysis_options.yaml).
    const _Step('Analyzer', 'flutter', ['analyze', '--fatal-infos']),
    if (!fast && Directory('test').existsSync())
      const _Step('Tests', 'flutter', ['test', '--reporter', 'failures-only']),
    if (!fast && File('scripts/agent/learn.dart').existsSync())
      const _Step('Lessons', 'dart', [
        'run',
        'scripts/agent/learn.dart',
        'check',
      ], echo: true),
    if (snapshot)
      const _Step('Snapshot', 'dart', ['run', 'scripts/agent/snapshot.dart']),
  ];

  for (var i = 0; i < steps.length; i++) {
    final step = steps[i];
    stdout.write('[${i + 1}/${steps.length}] ${step.label}... ');
    final sw = Stopwatch()..start();
    final result = await _run(fvm, step.exe, step.args);
    if (result.exitCode != 0) {
      print('FAILED');
      final cmd = fvm ? 'fvm ${step.exe}' : step.exe;
      print('\$ $cmd ${step.args.join(' ')}');
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      exitCode = 1;
      return;
    }
    print('ok (${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s)');
    if (step.echo) print('      ${(result.stdout as String).trim()}');
  }
  print('All quality gates passed.');
}

/// Returns true when FVM manages this project's SDK.
bool _useFvm() =>
    Directory('.fvm').existsSync() || File('.fvmrc').existsSync();

/// Runs a `dart` or `flutter` command through FVM when applicable.
Future<ProcessResult> _run(bool fvm, String exe, List<String> args) {
  if (fvm) return Process.run('fvm', [exe, ...args], runInShell: true);
  return Process.run(exe, args, runInShell: true);
}

class _Step {
  const _Step(this.label, this.exe, this.args, {this.echo = false});
  final String label;
  final String exe;
  final List<String> args;

  /// Print the tool's output on success too.
  final bool echo;
}

