import 'package:path/path.dart' as p;
import 'dart:io';

/// Matches the git dependency on the lints package in a pubspec, regardless
/// of which GitHub org the repository lives under.
final _lintsGitDep = RegExp(
    r'git:\s+url:\s+https://github\.com/[\w.-]+/Flutter-RxDart-Base\.git\s+path:\s+packages/redux_rxdart_lints');

const _lintsLocalDep = 'path: ../packages/redux_rxdart_lints';

class _SmokeFailure implements Exception {
  _SmokeFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Runs a command and throws [_SmokeFailure] (never `exit`) on a non-zero
/// exit code, so the `finally` cleanup in [main] always runs.
Future<ProcessResult> _run(
  String description,
  String executable,
  List<String> args, {
  String? workingDirectory,
  Duration timeout = const Duration(minutes: 15),
}) async {
  print('$description...');
  final result = await Process.run(
    executable,
    args,
    workingDirectory: workingDirectory,
    runInShell: true,
  ).timeout(timeout, onTimeout: () {
    throw _SmokeFailure('$description timed out after $timeout');
  });
  if (result.exitCode != 0) {
    throw _SmokeFailure(
        '$description failed (exit ${result.exitCode}).\n${result.stdout}\n${result.stderr}');
  }
  return result;
}

String _useLocalLints(String pubspec, String where) {
  if (!_lintsGitDep.hasMatch(pubspec)) {
    throw _SmokeFailure(
        'Could not find the redux_rxdart_lints git dependency in $where; '
        'the smoke test would otherwise validate GitHub main instead of '
        'this checkout.');
  }
  return pubspec.replaceFirst(_lintsGitDep, _lintsLocalDep);
}

Future<void> main() async {
  print('--- Starting cross-platform smoke test ---');

  final rootDir = Directory.current.path;
  final tempDir = Directory(p.join(rootDir, 'temp_smoke_test'));
  final templatePubspec =
      File(p.join(rootDir, 'bricks', 'project', '__brick__', 'pubspec.yaml'));
  final backupPubspecContent = templatePubspec.readAsStringSync();

  try {
    await _run('Activating mason_cli', 'dart',
        ['pub', 'global', 'activate', 'mason_cli']);
    await _run('Resolving workspace bricks via mason get', 'mason', ['get']);

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }

    // Point the template at the local lints package so the PR under test is
    // what gets validated.
    templatePubspec.writeAsStringSync(
        _useLocalLints(backupPubspecContent, 'the project brick pubspec'));

    await _run(
        'Creating fresh Flutter app', 'flutter', ['create', 'temp_smoke_test']);

    await _run('Running mason make project', 'mason', [
      'make',
      'project',
      '--project_name',
      'temp_smoke_test',
      '--android_package_name',
      'com.example.temp_smoke_test',
      '--ios_bundle_id',
      'com.example.temp_smoke_test',
      '--include_harness',
      'true',
      '--include_secure_storage',
      'true',
      '--on-conflict',
      'overwrite',
      '-o',
      'temp_smoke_test'
    ]);

    final generatedPubspec = File(p.join(tempDir.path, 'pubspec.yaml'));
    final generated = generatedPubspec.readAsStringSync();
    if (_lintsGitDep.hasMatch(generated)) {
      generatedPubspec.writeAsStringSync(
          _useLocalLints(generated, 'the generated pubspec'));
    } else if (!generated.contains(_lintsLocalDep)) {
      throw _SmokeFailure(
          'Generated pubspec does not reference redux_rxdart_lints.');
    }

    await _run(
      'Running mason make bloc',
      'mason',
      [
        'make',
        'bloc',
        '--feature_name',
        'dummy_feature',
        '--on-conflict',
        'overwrite',
      ],
      workingDirectory: tempDir.path,
    );

    await _run('Checking generated code is formatted', 'dart',
        ['format', '--set-exit-if-changed', '.'],
        workingDirectory: tempDir.path);
    await _run(
        'Running flutter analyze', 'flutter', ['analyze', '--fatal-infos'],
        workingDirectory: tempDir.path);
    final testRes = await _run(
        'Running flutter test',
        'flutter',
        [
          'test',
          '--reporter',
          'expanded',
        ],
        workingDirectory: tempDir.path);
    final testLines = (testRes.stdout as String).trim().split('\n');
    print('  ${testLines.last.trim()}');

    print('Running custom_lint...');
    final lintRes = await Process.run('dart', ['run', 'custom_lint'],
        workingDirectory: tempDir.path, runInShell: true);
    if (lintRes.exitCode != 0) {
      final combined = '${lintRes.stdout}\n${lintRes.stderr}';
      // Upstream custom_lint cannot handle spaces in parent directories.
      if (tempDir.path.contains(' ') && combined.contains('%20')) {
        print('Notice: skipping custom_lint failure caused by the upstream '
            'URI-encoding issue with spaces in the checkout path.');
      } else {
        throw _SmokeFailure('custom_lint failed.\n$combined');
      }
    }

    print('--- Smoke test completed successfully! ---');
  } on _SmokeFailure catch (e) {
    stderr.writeln('Smoke test failed: $e');
    exitCode = 1;
  } finally {
    // Always restore the template and remove the scratch app.
    templatePubspec.writeAsStringSync(backupPubspecContent);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}
