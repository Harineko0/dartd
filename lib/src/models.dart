/// Represents a single deletable module definition.
/// For example:
/// - @riverpod int foo(FooRef ref) => 0;
/// - final fooProvider = AutoDisposeProvider<int>(...);
class ModuleDefinition {
  final String baseName;
  final String name;
  final String filePath;
  final int start;
  final int end;
  final bool isProvider;
  final bool isRiverpod;

  ModuleDefinition({
    required this.baseName,
    required this.name,
    required this.filePath,
    required this.start,
    required this.end,
    required this.isProvider,
    required this.isRiverpod,
  });

  @override
  String toString() {
    final type = isProvider
        ? 'provider'
        : (isRiverpod ? 'riverpod' : 'module');
    return '$type "$name" in $filePath';
  }
}

/// Groups a riverpod function and its generated provider(s) by baseName.
/// Example:
/// - baseName: Foo
///   members: [@riverpod Foo(), FooProvider]
class ModuleGroup {
  final String baseName;
  final List<ModuleDefinition> members;

  ModuleGroup(this.baseName, this.members);
}

/// Result of analyzing the project.
class ProjectAnalysis {
  final Map<String, ModuleGroup> groupsByBaseName;

  /// Used names from non-generated user code.
  /// This is used only for deciding whether a module group is unused.
  final Set<String> usedNamesFromUserCode;

  /// Used names from all Dart files (including generated files).
  /// This is used for deciding whether a file containing non-module
  /// declarations can be safely deleted.
  final Set<String> usedNamesFromAllFiles;

  /// Files that contain at least one module definition.
  final Set<String> filesWithModules;

  /// All Dart files under the root.
  final List<String> allDartFiles;

  /// Non-module top level declarations per file.
  final Map<String, Set<String>> nonModuleDeclarationsByFile;

  ProjectAnalysis({
    required this.groupsByBaseName,
    required this.usedNamesFromUserCode,
    required this.usedNamesFromAllFiles,
    required this.filesWithModules,
    required this.allDartFiles,
    required this.nonModuleDeclarationsByFile,
  });
}
