import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// flutter_screenutil 5.9.3 does not rebuild widgets whose type name starts
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

  static const _widgetBases = <String>{'StatelessWidget', 'StatefulWidget'};

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

  /// A private widget class, or the State of a private StatefulWidget.
  bool _isPrivateWidget(ClassDeclaration node) {
    final superclass = node.extendsClause?.superclass;
    if (superclass == null) return false;
    final base = superclass.name.lexeme;
    if (_widgetBases.contains(base)) {
      return node.name.lexeme.startsWith('_');
    }
    if (base == 'State') {
      final args = superclass.typeArguments?.arguments;
      if (args == null || args.isEmpty) return false;
      final widget = args.first;
      return widget is NamedType && widget.name.lexeme.startsWith('_');
    }
    return false;
  }
}

class _Finder extends RecursiveAstVisitor<void> {
  _Finder(this.reporter, this.code);

  final DiagnosticReporter reporter;
  final LintCode code;

  bool _isNum(Expression? e) {
    final t = e?.staticType;
    return t != null &&
        (t.isDartCoreInt || t.isDartCoreDouble || t.isDartCoreNum);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (NoScreenutilInPrivateWidget._extensions.contains(
          node.propertyName.name,
        ) &&
        _isNum(node.target)) {
      reporter.atNode(node, code);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (NoScreenutilInPrivateWidget._extensions.contains(
          node.identifier.name,
        ) &&
        _isNum(node.prefix)) {
      reporter.atNode(node, code);
    }
    super.visitPrefixedIdentifier(node);
  }
}
