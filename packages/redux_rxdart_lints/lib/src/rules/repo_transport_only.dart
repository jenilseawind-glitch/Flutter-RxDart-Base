import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../lib_path.dart';

/// Golden Rule #1 (AGENTS.md): Repository is Transport ONLY.
/// Repository files MUST ONLY call `ApiBaseHelper` and return raw
/// `Map<String, dynamic>`. NEVER parse models in a Repository.
///
/// A repository file is any file under a `repo/` or `repository/` directory
/// in `lib/`, or named `*_repo.dart` / `*_repository.dart`.
/// Flags calls *and* tear-offs of `fromJson` / `fromMap`.
class RepoTransportOnly extends DartLintRule {
  RepoTransportOnly() : super(code: _code);

  static const _code = LintCode(
    name: 'repo_transport_only',
    problemMessage:
        'Repository must not parse models. Call .fromJson() in the BLoC, '
        'not in repo/ files (AGENTS.md Golden Rule #1).',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const _parsers = {'fromJson', 'fromMap'};

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final segments = libSegments(resolver);
    if (segments == null || !isRepoFile(segments)) return;

    // `Model.fromJson(x)` resolves to an InstanceCreationExpression for a
    // factory/named constructor, or a MethodInvocation for a static method.
    context.registry.addMethodInvocation((node) {
      if (_parsers.contains(node.methodName.name)) {
        reporter.atNode(node, _code);
      }
    });
    context.registry.addInstanceCreationExpression((node) {
      if (_parsers.contains(node.constructorName.name?.name)) {
        reporter.atNode(node, _code);
      }
    });
    // Tear-offs: `.map(Model.fromJson)`.
    context.registry.addConstructorReference((node) {
      if (_parsers.contains(node.constructorName.name?.name)) {
        reporter.atNode(node, _code);
      }
    });
    context.registry.addPrefixedIdentifier((node) {
      if (_parsers.contains(node.identifier.name) &&
          node.parent is! MethodInvocation) {
        reporter.atNode(node, _code);
      }
    });
  }

  static bool isRepoFile(List<String> segments) {
    final file = segments.last;
    return segments.contains('repo') ||
        segments.contains('repository') ||
        file.endsWith('_repo.dart') ||
        file.endsWith('_repository.dart');
  }
}
