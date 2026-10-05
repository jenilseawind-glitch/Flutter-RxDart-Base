import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../lib_path.dart';

/// Golden Rule #2 (AGENTS.md): Never display `e.toString()`.
/// Widgets must show errors with `error.userFacingMessage(context)`
/// (or let `AppResponseBuilder` do it).
class NoExceptionToString extends DartLintRule {
  NoExceptionToString() : super(code: _code);

  static const _code = LintCode(
    name: 'no_exception_tostring',
    problemMessage:
        'Never display e.toString() in UI. Use error.userFacingMessage(context) '
        'or AppResponseBuilder (AGENTS.md Golden Rule #2).',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only apply this rule in UI code (not in networking, redux, bloc, etc.)
    final segments = libSegments(resolver);
    if (segments == null || !_isUiCode(segments)) return;

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'toString') return;

      final target = node.target;
      if (target is SimpleIdentifier) {
        final name = target.name.toLowerCase();
        if (name == 'e' || name == 'err' || name == 'error' || name == 'exception') {
          reporter.atNode(node, _code);
        }
      }
    });
  }

  static bool _isUiCode(List<String> segments) {
    if (segments.isEmpty) return false;
    final root = segments.first;
    // Assume it's UI if it's in features or standard widgets, but definitely not:
    if (root == 'networking' || root == 'redux' || root == 'services') return false;
    if (segments.contains('bloc')) return false;
    if (segments.last.endsWith('_bloc.dart')) return false;
    if (segments.last.endsWith('_repo.dart')) return false;
    return true;
  }
}
