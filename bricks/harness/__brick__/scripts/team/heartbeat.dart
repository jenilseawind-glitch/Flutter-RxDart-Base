// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Inspects swarm state, sessions, and active tasks across single/multi-session modes.
///
/// Usage:
///   dart run scripts/team/heartbeat.dart
void main() {
  final queueFile = File('.harness/tasks/active.json');
  var pending = 0;
  var inProgress = 0;
  var completed = 0;
  var activeSessions = 0;

  if (queueFile.existsSync()) {
    try {
      final data = jsonDecode(queueFile.readAsStringSync()) as Map<String, dynamic>;
      final tasks = (data['tasks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final sessions = (data['sessions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      activeSessions = sessions.length;
      for (final t in tasks) {
        final status = t['status']?.toString();
        if (status == 'pending') pending++;
        if (status == 'in_progress') inProgress++;
        if (status == 'completed') completed++;
      }
    } catch (_) {}
  }

  final gitStatus = Process.runSync('git', ['status', '--short'], runInShell: true);
  final changedCount = (gitStatus.stdout as String)
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .length;

  print(
    'Heartbeat: sessions=$activeSessions in_progress=$inProgress pending=$pending completed=$completed | uncommitted_changes=$changedCount',
  );
}
