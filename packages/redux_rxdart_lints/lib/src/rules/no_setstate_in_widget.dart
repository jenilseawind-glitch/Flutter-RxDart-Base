import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../lib_path.dart';

/// Golden Rule #3 (AGENTS.md): Zero `setState`.
/// Drive UI from BLoC streams (`AppResponseBuilder`, `StreamBuilder`).
///
/// Only Flutter's `State.setState` is flagged (resolved, not by name), so
/// unrelated methods called `setState` are fine. The low-level design-system
/// primitives in `lib/utils/widgets/ui/` are exempt: they may hold purely
/// visual state (focus, obscured text) that never touches business logic.
class NoSetStateInWidget extends DartLintRule {
  NoSetStateInWidget() : super(code: _code);

  static const _code = LintCode(
    name: 'no_setstate_in_widget',
    problemMessage:
        'setState is forbidden. Drive UI from BLoC streams via '
        'AppResponseBuilder / StreamBuilder (AGENTS.md Golden Rule #3).',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final segments = libSegments(resolver);
    if (segments != null &&
        segments.length > 2 &&
        segments[0] == 'utils' &&
        segments[1] == 'widgets' &&
        segments[2] == 'ui') {
      return;
    }

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'setState') return;
      final element = node.methodName.element;
      final owner = element?.enclosingElement;
      final fromFlutter =
          element?.library?.uri.toString().startsWith('package:flutter/') ??
          false;
      if (owner?.name == 'State' && fromFlutter) {
        reporter.atNode(node, _code);
      }
    });
  }
}
