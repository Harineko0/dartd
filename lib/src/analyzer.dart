import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'usage_visitor.dart';
import 'utils.dart';

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

    final usedNamesFromUserCode = <String>{};
    final usedNamesFromAllFiles = <String>{};

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

        if (shouldIgnoreDirectory(name)) {
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

    final isGenerated = isGeneratedFile(filePath);

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
    final visitor = UsedNamesVisitor(target);
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
    final isRiverpod = decl.metadata.any(isRiverpodAnnotation);

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
      groupsByBaseName
          .putIfAbsent(name, () => <ModuleDefinition>[])
          .add(module);
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
    for (final variable in decl.variables.variables) {
      final name = variable.name.lexeme;
      if (name.endsWith(providerSuffix)) {
        onModuleFound();
        final baseName = baseNameFromProviderName(name);
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
    if (name.endsWith(providerSuffix)) {
      onModuleFound();
      final baseName = baseNameFromProviderName(name);
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
}

/// Compute which module groups are unused.
///
/// A group is considered "used" if:
/// - Any of its member names is referenced from user code, OR
/// - The baseName itself is referenced from user code.
///
/// Because we collect used names only from non-generated files,
/// references only inside *.g.dart / *.freezed.dart DO NOT mark usage.
List<ModuleGroup> computeUnusedGroups(
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
      for (final member in group.members) {
        if (usedNamesFromUserCode.contains(member.name)) {
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
Set<String> computeDeletableNonModuleFiles(ProjectAnalysis analysis) {
  final deletable = <String>{};

  for (final filePath in analysis.allDartFiles) {
    if (isGeneratedFile(filePath)) {
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
    final isUsed = declared.any(analysis.usedNamesFromAllFiles.contains);

    if (!isUsed) {
      deletable.add(filePath);
    }
  }

  return deletable;
}

/// Apply in-place fixes to delete module definitions from files.
/// If a file becomes empty (only whitespace) after modifications,
/// it will be deleted.
void applyFixes(Map<String, List<ModuleDefinition>> modulesToDeleteByFile) {
  for (final entry in modulesToDeleteByFile.entries) {
    final filePath = entry.key;
    final file = File(filePath);
    if (!file.existsSync()) continue;

    var content = file.readAsStringSync();
    final modules = entry.value.toList()
      ..sort((a, b) => b.start.compareTo(a.start)); // Delete from bottom

    for (final module in modules) {
      content = content.replaceRange(module.start, module.end, '');
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
