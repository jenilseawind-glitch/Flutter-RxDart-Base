import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Path segments of the analysed file relative to the package's `lib/`
/// directory, e.g. `['features', 'auth', 'repo', 'auth_repo.dart']`.
///
/// Returns `null` for files outside `lib/` (tests, tool scripts).
///
/// Matching on the lib-relative path — never the absolute path — keeps the
/// rules independent of where the project is checked out (a CI workspace
/// named `/repo/` or a home folder named `utils/` must not change results).
List<String>? libSegments(CustomLintResolver resolver) {
  final path = resolver.source.fullName.replaceAll('\\', '/');
  final index = path.lastIndexOf('/lib/');
  if (index == -1) return null;
  return path.substring(index + '/lib/'.length).split('/');
}
