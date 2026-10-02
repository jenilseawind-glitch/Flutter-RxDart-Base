import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../lib_path.dart';

/// Golden Rule #4 (AGENTS.md): Zero RxDart Outside BLoC.
/// UI widgets must never import RxDart (`BehaviorSubject`, `PublishSubject`).
/// UI widgets only consume standard `Stream<T>` / `ApiResponse<T>`.
///
/// RxDart is allowed in:
/// - any `bloc/` directory or `*_bloc.dart` file (including the nested
///   `utils/widgets/view/<component>/bloc/` BLoCs),
/// - `redux/`, `networking/` and `services/`,
/// - `utils/` helpers, except `utils/widgets/` (which is UI).
class NoRxdartInUi extends DartLintRule {
  NoRxdartInUi() : super(code: _code);

  static const _code = LintCode(
    name: 'no_rxdart_in_ui',
    problemMessage:
        'RxDart must not be imported outside bloc/ files. UI widgets consume '
        'Stream<T> / ApiResponse<T> only (AGENTS.md Golden Rule #4).',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const _nonUiRoots = {'redux', 'networking', 'services'};

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final segments = libSegments(resolver);
    if (segments == null || isAllowed(segments)) return;

    void check(NamespaceDirective node) {
      final uri = node.uri.stringValue ?? '';
      if (uri.startsWith('package:rxdart/')) reporter.atNode(node, _code);
    }

    context.registry.addImportDirective(check);
    context.registry.addExportDirective(check);
  }

  /// Visible for the rule's own reasoning; [segments] is lib-relative.
  static bool isAllowed(List<String> segments) {
    if (segments.last.endsWith('_bloc.dart')) return true;
    if (segments.contains('bloc')) return true;
    final root = segments.first;
    if (_nonUiRoots.contains(root)) return true;
    if (root == 'utils') {
      return segments.length < 2 || segments[1] != 'widgets';
    }
    return false;
  }
}
