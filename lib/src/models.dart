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
    final type = isProvider ? 'provider' : (isRiverpod ? 'riverpod' : 'module');
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

/// Kind of class member.
enum ClassMemberKind { method, getter, setter, field }

class OffsetRange {
  final int start;
  final int end;

  const OffsetRange(this.start, this.end);
}

/// Represents a deletable class member such as a method or accessor.
class ClassMemberDefinition {
  final String className;
  final String name;
  final String filePath;
  final int start;
  final int end;
  final ClassMemberKind kind;
  final bool isStatic;
  final List<OffsetRange> extraRanges;

  ClassMemberDefinition({
    required this.className,
    required this.name,
    required this.filePath,
    required this.start,
    required this.end,
    required this.kind,
    required this.isStatic,
    this.extraRanges = const [],
  });

  @override
  String toString() {
    final staticPrefix = isStatic ? 'static ' : '';
    final label = switch (kind) {
      ClassMemberKind.field => 'field',
      ClassMemberKind.getter => 'getter',
      ClassMemberKind.setter => 'setter',
      ClassMemberKind.method => 'method',
    };
    return '$staticPrefix$label "$name" in $className ($filePath)';
  }
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

  /// Collected class members that can be evaluated for removal.
  final List<ClassMemberDefinition> classMembers;

  ProjectAnalysis({
    required this.groupsByBaseName,
    required this.usedNamesFromUserCode,
    required this.usedNamesFromAllFiles,
    required this.filesWithModules,
    required this.allDartFiles,
    required this.nonModuleDeclarationsByFile,
    required this.classMembers,
  });
}
