#!/usr/bin/env dart
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

/// Exit code used when CLI usage is invalid.
const _exitCodeUsage = 64;

/// Directories ignored during analysis.
const _ignoredDirectories = <String>{
  '.dart_tool',
  'build',
  'build_web',
};

/// Suffix for provider names.
const _providerSuffix = 'Provider';

/// Common suffixes for generated Dart files.
const _generatedFileSuffixes = <String>[
  '.g.dart',
  '.freezed.dart',
  '.gen.dart',
];

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

/// CLI entry point.
Future<void> main(List<String> args) async {
  final cli = _DartdCli();
  final exitCode = await cli.run(args);
  exit(exitCode);
}

/// Handles argument parsing and command dispatch.
class _DartdCli {
  _DartdCli() : _parser = _buildParser();

  final ArgParser _parser;

  static ArgParser _buildParser() {
    final analyzeCommand = ArgParser()
      ..addOption(
        'root',
        abbr: 'r',
        defaultsTo: 'lib',
        help: 'Root directory to analyze.',
      );

    final fixCommand = ArgParser()
      ..addOption(
        'root',
        abbr: 'r',
        defaultsTo: 'lib',
        help: 'Root directory to analyze and fix.',
      );

    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      )
      ..addCommand('analyze', analyzeCommand)
      ..addCommand('fix', fixCommand);
  }

  Future<int> run(List<String> args) async {
    final results = _parseArgs(args);
    if (results == null) {
      _printUsage(_parser);
      return _exitCodeUsage;
    }

    if (results['help'] == true || results.command == null) {
      _printUsage(_parser);
      return 0;
    }

    final command = results.command!;
    final rootOption = command['root'] as String? ?? 'lib';
    final rootPath = p.normalize(p.absolute(rootOption));

    if (!Directory(rootPath).existsSync()) {
      stderr.writeln('Root directory does not exist: $rootPath');
      return _exitCodeUsage;
    }

    switch (command.name) {
      case 'analyze':
        await _runAnalyze(rootPath);
        return 0;
      case 'fix':
        await _runFix(rootPath);
        return 0;
      default:
        stderr.writeln('Unknown command: ${command.name}');
        _printUsage(_parser);
        return _exitCodeUsage;
    }
  }

  ArgResults? _parseArgs(List<String> args) {
    try {
      return _parser.parse(args);
    } on ArgParserException catch (e) {
      stderr.writeln(e.message);
      return null;
    }
  }
}

void _printUsage(ArgParser parser) {
  print('''
Flutter unused module cleaner

Usage:
  dart run bin/unused_code_cleaner.dart analyze --root lib
  dart run bin/unused_code_cleaner.dart fix --root lib

Commands:
  analyze   Analyze unused riverpod modules.
  fix       Remove unused riverpod modules and empty module files.

Options:
${parser.usage}
''');
}

/// Entry point for `analyze` command.
Future<void> _runAnalyze(String rootPath) async {
  print('Analyzing project under: $rootPath');

  final analysis = await analyzeProject(rootPath);

  final unusedGroups = _computeUnusedGroups(
    analysis.groupsByBaseName,
    analysis.usedNamesFromUserCode,
  );

  if (unusedGroups.isEmpty) {
    print('No unused modules found.');
  } else {
    print('=== Unused modules ===');
    for (final group in unusedGroups) {
      print('- Base name: ${group.baseName}');
      for (final module in group.members) {
        // Do not touch generated files like *.g.dart / *.freezed.dart.
        if (_isGeneratedFile(module.filePath)) {
          continue;
        }
        print('    - $module');
      }
    }
  }

  final deletableFiles =
  _computeDeletableNonModuleFiles(analysis).toList()..sort();

  if (deletableFiles.isEmpty) {
    print('No files without used module or non-module definitions.');
  } else {
    print(
      '\n=== Files without any used module/non-module definitions (deletable) ===',
    );
    for (final file in deletableFiles) {
      print('- $file');
    }
  }
}

/// Entry point for `fix` command.
/// Actually removes unused modules and deletes empty module files.
Future<void> _runFix(String rootPath) async {
  print('Analyzing project under: $rootPath');

  final analysis = await analyzeProject(rootPath);

  final unusedGroups = _computeUnusedGroups(
    analysis.groupsByBaseName,
    analysis.usedNamesFromUserCode,
  );

  if (unusedGroups.isEmpty) {
    print('No unused modules found. Nothing to fix.');
  } else {
    print('Removing unused modules...');
    final modulesToDeleteByFile = <String, List<ModuleDefinition>>{};

    for (final group in unusedGroups) {
      for (final m in group.members) {
        // Do not touch generated files like *.g.dart / *.freezed.dart.
        if (_isGeneratedFile(m.filePath)) {
          continue;
        }

        modulesToDeleteByFile.putIfAbsent(m.filePath, () => []).add(m);
      }
    }

    _applyFixes(modulesToDeleteByFile);
  }

  // Delete files with no used module/non-module definitions.
  final deletableFiles =
  _computeDeletableNonModuleFiles(analysis).toList()..sort();

  if (deletableFiles.isEmpty) {
    print('No files without module/non-module definitions to delete.');
  } else {
    print('\nDeleting files with no used module/non-module definitions...');
    for (final filePath in deletableFiles) {
      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
        print('Deleted file: $filePath');
      }
    }
  }

  print('Fix completed.');
}

/// Public API for analyzing a project. Useful for tests / library usage.
Future<ProjectAnalysis> analyzeProject(String rootPath) {
  return ProjectAnalyzer(rootPath).analyze();
}

/// Encapsulates project-wide analysis.
class ProjectAnalyzer {
  ProjectAnalyzer(this.rootPath);

  final String rootPath;

  Future<ProjectAnalysis> analyze() async {
    final allFiles = _collectDartFiles();

    final groupsByBaseName = <String, List<ModuleDefinition>>{};
    final filesWithModules = <String>{};

    // Usage sets
    final usedNamesFromUserCode = <String>{};
    final usedNamesFromAllFiles = <String>{};

    // Non-module declarations per file
    final nonModuleDeclarationsByFile = <String, Set<String>>{};

    for (final filePath in allFiles) {
      await _analyzeFile(
        filePath: filePath,
        groupsByBaseName: groupsByBaseName,
        filesWithModules: filesWithModules,
        usedNamesFromUserCode: usedNamesFromUserCode,
        usedNamesFromAllFiles: usedNamesFromAllFiles,
        nonModuleDeclarationsByFile: nonModuleDeclarationsByFile,
      );
    }

    final groups = <String, ModuleGroup>{
      for (final entry in groupsByBaseName.entries)
        entry.key: ModuleGroup(entry.key, entry.value),
    };

    return ProjectAnalysis(
      groupsByBaseName: groups,
      usedNamesFromUserCode: usedNamesFromUserCode,
      usedNamesFromAllFiles: usedNamesFromAllFiles,
      filesWithModules: filesWithModules,
      allDartFiles: allFiles,
      nonModuleDeclarationsByFile: nonModuleDeclarationsByFile,
    );
  }

  List<String> _collectDartFiles() {
    final dartFiles = <String>[];

    void collect(Directory dir) {
      for (final entity in dir.listSync(recursive: false, followLinks: false)) {
        final name = p.basename(entity.path);

        if (_shouldIgnoreDirectory(name)) {
          continue;
        }

        if (entity is Directory) {
          collect(entity);
        } else if (entity is File && entity.path.endsWith('.dart')) {
          dartFiles.add(p.normalize(entity.path));
        }
      }
    }

    collect(Directory(rootPath));
    return dartFiles;
  }

  Future<void> _analyzeFile({
    required String filePath,
    required Map<String, List<ModuleDefinition>> groupsByBaseName,
    required Set<String> filesWithModules,
    required Set<String> usedNamesFromUserCode,
    required Set<String> usedNamesFromAllFiles,
    required Map<String, Set<String>> nonModuleDeclarationsByFile,
  }) async {
    final unit = await _parseCompilationUnit(filePath);
    if (unit == null) return;

    final isGenerated = _isGeneratedFile(filePath);

    // 1) Collect used symbol names from ALL files.
    _collectUsedNames(unit, usedNamesFromAllFiles);

    // 2) Collect used symbol names from non-generated user code only.
    if (!isGenerated) {
      _collectUsedNames(unit, usedNamesFromUserCode);
    }

    // 3) Collect module definitions and non-module top level declarations.
    final nonModuleNames = _collectDeclarationsAndModules(
      unit: unit,
      filePath: filePath,
      groupsByBaseName: groupsByBaseName,
      filesWithModules: filesWithModules,
    );

    if (nonModuleNames.isNotEmpty) {
      nonModuleDeclarationsByFile[filePath] = nonModuleNames;
    }
  }

  Future<CompilationUnit?> _parseCompilationUnit(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final content = await file.readAsString();
    final parseResult = parseString(
      content: content,
      path: filePath,
      throwIfDiagnostics: false,
    );
    return parseResult.unit;
  }

  void _collectUsedNames(CompilationUnit unit, Set<String> target) {
    final visitor = _UsedNamesVisitor(target);
    unit.accept(visitor);
  }

  Set<String> _collectDeclarationsAndModules({
    required CompilationUnit unit,
    required String filePath,
    required Map<String, List<ModuleDefinition>> groupsByBaseName,
    required Set<String> filesWithModules,
  }) {
    final nonModuleNames = <String>{};
    var hasModuleInFile = false;

    for (final decl in unit.declarations) {
      if (decl is FunctionDeclaration) {
        _handleFunctionDeclaration(
          decl: decl,
          filePath: filePath,
          groupsByBaseName: groupsByBaseName,
          nonModuleNames: nonModuleNames,
          onModuleFound: () => hasModuleInFile = true,
        );
      } else if (decl is TopLevelVariableDeclaration) {
        _handleTopLevelVariableDeclaration(
          decl: decl,
          filePath: filePath,
          groupsByBaseName: groupsByBaseName,
          nonModuleNames: nonModuleNames,
          onModuleFound: () => hasModuleInFile = true,
        );
      } else if (decl is ClassDeclaration) {
        _handleClassDeclaration(
          decl: decl,
          filePath: filePath,
          groupsByBaseName: groupsByBaseName,
          nonModuleNames: nonModuleNames,
          onModuleFound: () => hasModuleInFile = true,
        );
      } else if (decl is EnumDeclaration) {
        nonModuleNames.add(decl.name.lexeme);
      } else if (decl is GenericTypeAlias) {
        nonModuleNames.add(decl.name.lexeme);
      } else if (decl is ExtensionDeclaration) {
        _handleExtensionDeclaration(
          decl: decl,
          nonModuleNames: nonModuleNames,
        );
      }
    }

    if (hasModuleInFile) {
      filesWithModules.add(filePath);
    }

    return nonModuleNames;
  }

  void _handleFunctionDeclaration({
    required FunctionDeclaration decl,
    required String filePath,
    required Map<String, List<ModuleDefinition>> groupsByBaseName,
    required Set<String> nonModuleNames,
    required void Function() onModuleFound,
  }) {
    final name = decl.name.lexeme;
    final isRiverpod = decl.metadata.any(_isRiverpodAnnotation);

    if (isRiverpod) {
      onModuleFound();
      final module = ModuleDefinition(
        baseName: name,
        name: name,
        filePath: filePath,
        start: decl.offset,
        end: decl.end,
        isProvider: false,
        isRiverpod: true,
      );
      groupsByBaseName.putIfAbsent(name, () => <ModuleDefinition>[]).add(module);
    } else {
      nonModuleNames.add(name);
    }
  }

  void _handleTopLevelVariableDeclaration({
    required TopLevelVariableDeclaration decl,
    required String filePath,
    required Map<String, List<ModuleDefinition>> groupsByBaseName,
    required Set<String> nonModuleNames,
    required void Function() onModuleFound,
  }) {
    for (final v in decl.variables.variables) {
      final name = v.name.lexeme;
      if (name.endsWith(_providerSuffix)) {
        onModuleFound();
        final baseName = _baseNameFromProviderName(name);
        final module = ModuleDefinition(
          baseName: baseName,
          name: name,
          filePath: filePath,
          start: decl.offset,
          end: decl.end,
          isProvider: true,
          isRiverpod: false,
        );
        groupsByBaseName
            .putIfAbsent(baseName, () => <ModuleDefinition>[])
            .add(module);
      } else {
        nonModuleNames.add(name);
      }
    }
  }

  void _handleClassDeclaration({
    required ClassDeclaration decl,
    required String filePath,
    required Map<String, List<ModuleDefinition>> groupsByBaseName,
    required Set<String> nonModuleNames,
    required void Function() onModuleFound,
  }) {
    final name = decl.name.lexeme;
    if (name.endsWith(_providerSuffix)) {
      onModuleFound();
      final baseName = _baseNameFromProviderName(name);
      final module = ModuleDefinition(
        baseName: baseName,
        name: name,
        filePath: filePath,
        start: decl.offset,
        end: decl.end,
        isProvider: true,
        isRiverpod: false,
      );
      groupsByBaseName
          .putIfAbsent(baseName, () => <ModuleDefinition>[])
          .add(module);
    } else {
      nonModuleNames.add(name);
    }
  }

  void _handleExtensionDeclaration({
    required ExtensionDeclaration decl,
    required Set<String> nonModuleNames,
  }) {
    if (decl.name != null) {
      nonModuleNames.add(decl.name!.lexeme);
    }

    for (final member in decl.members) {
      if (member is MethodDeclaration) {
        if (member.name.lexeme.isNotEmpty) {
          nonModuleNames.add(member.name.lexeme);
        }
      } else if (member is FieldDeclaration) {
        for (final v in member.fields.variables) {
          nonModuleNames.add(v.name.lexeme);
        }
      }
    }
  }

  bool _shouldIgnoreDirectory(String name) {
    if (name.startsWith('.')) return true;
    return _ignoredDirectories.contains(name);
  }
}

/// Visitor that collects every referenced identifier name from a compilation unit,
/// but ignores declaration contexts (e.g. function names, class names).
class _UsedNamesVisitor extends RecursiveAstVisitor<void> {
  final Set<String> usedNames;

  _UsedNamesVisitor(this.usedNames);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!node.inDeclarationContext()) {
      usedNames.add(node.name);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    // Always treat the type name as a usage.
    final identifier = node.name2;
    usedNames.add(identifier.lexeme);
    super.visitNamedType(node);
  }
}

/// Decide if an annotation is a "@riverpod" annotation.
/// This checks the simple name, so it works for both:
/// - @riverpod
/// - @riverpodAnnotation.riverpod
bool _isRiverpodAnnotation(Annotation annotation) {
  final name = annotation.name;
  if (name is PrefixedIdentifier) {
    return name.identifier.name == 'riverpod';
  } else if (name is SimpleIdentifier) {
    return name.name == 'riverpod';
  }
  return false;
}

/// Extracts base name from a provider name.
/// For example:
///   FooProvider -> Foo
///   fooProvider -> foo
String _baseNameFromProviderName(String name) {
  if (name.endsWith(_providerSuffix)) {
    return name.substring(0, name.length - _providerSuffix.length);
  }
  return name;
}

/// Determine if the given file path is a generated file that should not
/// contribute to "usage" information.
///
/// We still remove definitions inside generated files when they belong
/// to an unused module group, but any references *inside* these files
/// do not count as usage.
///
/// This behavior ensures that:
/// - FooProvider only referenced from foo.g.dart does NOT mark it as used.
/// - If FooProvider is referenced from user code files, it is treated as used.
bool _isGeneratedFile(String filePath) {
  return _generatedFileSuffixes.any(filePath.endsWith);
}

/// Compute which module groups are unused.
///
/// A group is considered "used" if:
/// - Any of its member names is referenced from user code, OR
/// - The baseName itself is referenced from user code.
///
/// Because we collect used names only from non-generated files,
/// references only inside *.g.dart / *.freezed.dart DO NOT mark usage.
List<ModuleGroup> _computeUnusedGroups(
    Map<String, ModuleGroup> groupsByBaseName,
    Set<String> usedNamesFromUserCode,
    ) {
  final unused = <ModuleGroup>[];

  for (final group in groupsByBaseName.values) {
    var isUsed = false;

    // If the base name is used directly, the whole group is used.
    if (usedNamesFromUserCode.contains(group.baseName)) {
      isUsed = true;
    } else {
      // If any member is used, the whole group is used.
      for (final m in group.members) {
        if (usedNamesFromUserCode.contains(m.name)) {
          isUsed = true;
          break;
        }
      }
    }

    if (!isUsed) {
      unused.add(group);
    }
  }

  return unused;
}

/// Compute deletable files that do not contain any module definitions.
///
/// A file is deletable if:
/// - It is not a generated file (.g.dart, .freezed.dart, .gen.dart), AND
/// - It does not contain any module definitions (@riverpod or *Provider), AND
/// - It is not a main.dart file, AND
/// - None of its non-module top level declarations are referenced
///   anywhere in the project (including generated files).
Set<String> _computeDeletableNonModuleFiles(ProjectAnalysis analysis) {
  final deletable = <String>{};

  for (final filePath in analysis.allDartFiles) {
    if (_isGeneratedFile(filePath)) {
      // Do not delete generated files via this logic.
      continue;
    }

    // Never treat main.dart as deletable.
    if (p.basename(filePath) == 'main.dart') {
      continue;
    }

    // Files that contain modules are handled by module-level deletions.
    if (analysis.filesWithModules.contains(filePath)) {
      continue;
    }

    final declared =
        analysis.nonModuleDeclarationsByFile[filePath] ?? const <String>{};

    // If any non-module declaration is used anywhere (including generated
    // files), this file should not be deleted.
    final isUsed =
    declared.any(analysis.usedNamesFromAllFiles.contains);

    if (!isUsed) {
      deletable.add(filePath);
    }
  }

  return deletable;
}

/// Apply in-place fixes to delete module definitions from files.
/// If a file becomes empty (only whitespace) after modifications,
/// it will be deleted.
void _applyFixes(Map<String, List<ModuleDefinition>> modulesToDeleteByFile) {
  for (final entry in modulesToDeleteByFile.entries) {
    final filePath = entry.key;
    final file = File(filePath);
    if (!file.existsSync()) continue;

    var content = file.readAsStringSync();
    final modules = entry.value.toList()
      ..sort((a, b) => b.start.compareTo(a.start)); // Delete from bottom

    for (final m in modules) {
      // Remove the range corresponding to this declaration.
      content = content.replaceRange(m.start, m.end, '');
    }

    if (content.trim().isEmpty) {
      file.deleteSync();
      print('Deleted empty file after removing modules: $filePath');
    } else {
      file.writeAsStringSync(content);
      print('Updated file: $filePath');
    }
  }
}
