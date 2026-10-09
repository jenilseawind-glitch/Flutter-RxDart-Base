// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Manages task handoffs and session state across single and multi-session modes
/// in `.harness/tasks/active.json`.
///
/// Usage:
/// ```bash
/// dart run scripts/team/task_handoff.dart list
/// dart run scripts/team/task_handoff.dart sessions
/// dart run scripts/team/task_handoff.dart register-session --session "<id>" --agent "<agent>"
/// dart run scripts/team/task_handoff.dart create --title "<title>" --assignee "<agent>" [--desc "<desc>"] [--session "<id>"]
/// dart run scripts/team/task_handoff.dart claim --id "<id>" --assignee "<agent>" [--session "<id>"]
/// dart run scripts/team/task_handoff.dart complete --id "<id>" [--summary "<summary>"] [--session "<id>"]
/// ```
void main(List<String> args) {
  if (args.isEmpty) {
    _printUsage();
    return;
  }

  final command = args.first;
  final queueFile = File('.harness/tasks/active.json');
  if (!queueFile.existsSync()) {
    queueFile.parent.createSync(recursive: true);
    _atomicSave(queueFile, {
      'sessions': <Map<String, dynamic>>[],
      'tasks': <Map<String, dynamic>>[],
    });
  }

  final data = _readJsonSafe(queueFile);
  final tasks = (data['tasks'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();
  final sessions = (data['sessions'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();

  switch (command) {
    case 'list':
      _listTasks(tasks);
      break;

    case 'sessions':
      _listSessions(sessions);
      break;

    case 'register-session':
      final sessionId = _argValue(args, '--session') ?? 'session-${DateTime.now().millisecondsSinceEpoch}';
      final agent = _argValue(args, '--agent') ?? 'general';
      sessions.removeWhere((s) => s['id'] == sessionId);
      sessions.add({
        'id': sessionId,
        'agent': agent,
        'registered_at': DateTime.now().toUtc().toIso8601String(),
        'last_active': DateTime.now().toUtc().toIso8601String(),
      });
      _atomicSave(queueFile, {'sessions': sessions, 'tasks': tasks});
      print('Registered session: $sessionId as @$agent');
      break;

    case 'create':
      final title = _argValue(args, '--title');
      final assignee = _argValue(args, '--assignee') ?? 'unassigned';
      final desc = _argValue(args, '--desc') ?? '';
      final session = _argValue(args, '--session');
      if (title == null || title.isEmpty) {
        stderr.writeln('Error: --title is required.');
        exit(1);
      }
      final id = 'T-${DateTime.now().millisecondsSinceEpoch}';
      final newTask = {
        'id': id,
        'title': title,
        'assignee': assignee,
        'description': desc,
        'status': 'pending',
        'created_by_session': session ?? 'unknown',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      tasks.add(newTask);
      _atomicSave(queueFile, {'sessions': sessions, 'tasks': tasks});
      print('Task created: $id ($title) -> $assignee');
      break;

    case 'claim':
      final id = _argValue(args, '--id');
      final assignee = _argValue(args, '--assignee');
      final session = _argValue(args, '--session');
      final force = args.contains('--force');
      if (id == null || assignee == null) {
        stderr.writeln('Error: --id and --assignee are required.');
        exit(1);
      }
      final task = tasks.firstWhere(
        (t) => t['id'] == id,
        orElse: () => {},
      );
      if (task.isEmpty) {
        stderr.writeln('Error: Task $id not found.');
        exit(1);
      }
      if (task['status'] == 'in_progress' && !force) {
        final currentAssignee = task['assignee'];
        final currentSession = task['claimed_by_session'] ?? 'another session';
        stderr.writeln(
          'Conflict: Task $id is already in progress by @$currentAssignee ($currentSession). Use --force to override.',
        );
        exit(1);
      }
      task['assignee'] = assignee;
      task['status'] = 'in_progress';
      if (session != null) task['claimed_by_session'] = session;
      task['updated_at'] = DateTime.now().toUtc().toIso8601String();
      _atomicSave(queueFile, {'sessions': sessions, 'tasks': tasks});
      print('Task $id claimed by $assignee${session != null ? " ($session)" : ""}');
      break;

    case 'complete':
      final id = _argValue(args, '--id');
      final summary = _argValue(args, '--summary') ?? '';
      final session = _argValue(args, '--session');
      if (id == null) {
        stderr.writeln('Error: --id is required.');
        exit(1);
      }
      final task = tasks.firstWhere(
        (t) => t['id'] == id,
        orElse: () => {},
      );
      if (task.isEmpty) {
        stderr.writeln('Error: Task $id not found.');
        exit(1);
      }
      task['status'] = 'completed';
      if (summary.isNotEmpty) task['completion_summary'] = summary;
      if (session != null) task['completed_by_session'] = session;
      task['completed_at'] = DateTime.now().toUtc().toIso8601String();
      _atomicSave(queueFile, {'sessions': sessions, 'tasks': tasks});
      print('Task $id marked completed.');
      break;

    default:
      _printUsage();
      break;
  }
}

Map<String, dynamic> _readJsonSafe(File file) {
  try {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    return {
      'sessions': <Map<String, dynamic>>[],
      'tasks': <Map<String, dynamic>>[],
    };
  }
}

void _listTasks(List<Map<String, dynamic>> tasks) {
  if (tasks.isEmpty) {
    print('No active tasks in queue.');
    return;
  }
  print('Active Task Queue (${tasks.length} tasks):');
  for (final t in tasks) {
    final sessionInfo = t['claimed_by_session'] != null ? ' [${t['claimed_by_session']}]' : '';
    print('  [${t['status']}] ${t['id']}: ${t['title']} (@${t['assignee']}$sessionInfo)');
  }
}

void _listSessions(List<Map<String, dynamic>> sessions) {
  if (sessions.isEmpty) {
    print('No active sessions registered.');
    return;
  }
  print('Registered Sessions (${sessions.length}):');
  for (final s in sessions) {
    print('  ${s['id']} (@${s['agent']}) - last active: ${s['last_active']}');
  }
}

void _atomicSave(File file, Map<String, dynamic> state) {
  final content = const JsonEncoder.withIndent('  ').convert(state);
  final tempFile = File('${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}');
  tempFile.writeAsStringSync(content, flush: true);

  if (Platform.isWindows) {
    try {
      if (file.existsSync()) file.deleteSync();
      tempFile.renameSync(file.path);
    } catch (_) {
      file.writeAsStringSync(content, flush: true);
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }
  } else {
    tempFile.renameSync(file.path);
  }
}

String? _argValue(List<String> args, String name) {
  final idx = args.indexOf(name);
  if (idx != -1 && idx + 1 < args.length) {
    return args[idx + 1];
  }
  return null;
}

void _printUsage() {
  print('Usage:');
  print('  dart run scripts/team/task_handoff.dart list');
  print('  dart run scripts/team/task_handoff.dart sessions');
  print('  dart run scripts/team/task_handoff.dart register-session --session "<id>" --agent "<agent>"');
  print('  dart run scripts/team/task_handoff.dart create --title "<title>" --assignee "<agent>" [--desc "<desc>"] [--session "<id>"]');
  print('  dart run scripts/team/task_handoff.dart claim --id "<id>" --assignee "<agent>" [--session "<id>"] [--force]');
  print('  dart run scripts/team/task_handoff.dart complete --id "<id>" [--summary "<summary>"] [--session "<id>"]');
}
