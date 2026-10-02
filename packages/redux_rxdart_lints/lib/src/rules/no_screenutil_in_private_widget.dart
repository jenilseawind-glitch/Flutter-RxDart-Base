import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// flutter_screenutil (5.9.x) does not rebuild widgets whose type name starts
/// with `_` when the window size changes (and its `SU` mixin does not fix it).
/// A private widget using `.w/.h/.r/.sp` therefore keeps stale sizes after
/// rotation, split-screen or tablet resize. Make the widget public instead.
class NoScreenutilInPrivateWidget extends DartLintRule {
  NoScreenutilInPrivateWidget() : super(code: _code);

  static const _code = LintCode(
    name: 'no_screenutil_in_private_widget',
    problemMessage:
        'ScreenUtil size extensions (.w .h .r .sp ...) in a private widget '
        'are not rebuilt on resize. Make the widget public (no leading _).',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const _extensions = <String>{
    'w',
    'h',
    'r',
    'sp',
    'sw',
    'sh',
    'dg',
    'dm',
    'spMin',
    'spMax',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      if (!_isPrivateWidget(node)) return;
      node.accept(_Finder(reporter, _code));
    });
  }

  /// A private widget class (any Widget subtype: StatelessWidget,
  /// StatefulWidget, ConsumerWidget, HookWidget, ...) or the State of a
  /// private StatefulWidget. Resolved through the type hierarchy, not by
  /// the name of the direct superclass.
  bool _isPrivateWidget(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null) return false;
    for (final type in element.allSupertypes) {
      final name = type.element.name;
      if (name == 'Widget' && node.name.lexeme.startsWith('_')) return true;
      if (name == 'State' && type.typeArguments.isNotEmpty) {
        final widget = type.typeArguments.first.element?.name;
        if (widget != null && widget.startsWith('_')) return true;
      }
    }
    return false;
  }
}

class _Finder extends RecursiveAstVisitor<void> {
  _Finder(this.reporter, this.code);

  final DiagnosticReporter reporter;
  final LintCode code;

  /// True when [id] resolves to an extension member declared in
  /// flutter_screenutil — a user extension also named `.w` is ignored.
  bool _isScreenUtil(SimpleIdentifier id) {
    if (!NoScreenutilInPrivateWidget._extensions.contains(id.name)) {
      return false;
    }
    final uri = id.element?.library?.uri.toString() ?? '';
    return uri.startsWith('package:flutter_screenutil/');
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (_isScreenUtil(node.propertyName)) {
      reporter.atNode(node, code);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (_isScreenUtil(node.identifier)) {
      reporter.atNode(node, code);
    }
    super.visitPrefixedIdentifier(node);
  }
}
