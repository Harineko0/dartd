import 'package:analyzer/dart/ast/ast.dart';

/// Directories ignored during analysis.
const ignoredDirectories = <String>{
  '.dart_tool',
  'build',
  'build_web',
};

/// Suffix for provider names.
const providerSuffix = 'Provider';

/// Common suffixes for generated Dart files.
const generatedFileSuffixes = <String>[
  '.g.dart',
  '.freezed.dart',
  '.gen.dart',
];

/// Determine if the given file path is a generated file that should not
/// contribute to "usage" information.
bool isGeneratedFile(String filePath) {
  return generatedFileSuffixes.any(filePath.endsWith);
}

/// Extracts base name from a provider name.
/// For example:
///   FooProvider -> Foo
///   fooProvider -> foo
String baseNameFromProviderName(String name) {
  if (name.endsWith(providerSuffix)) {
    return name.substring(0, name.length - providerSuffix.length);
  }
  return name;
}

/// Decide if an annotation is a "@riverpod" annotation.
///
/// This checks the simple name, so it works for both:
/// - @riverpod
/// - @riverpodAnnotation.riverpod
bool isRiverpodAnnotation(Annotation annotation) {
  final name = annotation.name;
  if (name is PrefixedIdentifier) {
    return name.identifier.name == 'riverpod';
  } else if (name is SimpleIdentifier) {
    return name.name == 'riverpod';
  }
  return false;
}

/// Whether a directory should be ignored during traversal.
bool shouldIgnoreDirectory(String name) {
  if (name.startsWith('.')) return true;
  return ignoredDirectories.contains(name);
}
