import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'usage_visitor.dart';
import 'utils.dart';

const _implicitlyUsedMemberNames = {'toString', 'hashCode', 'noSuchMethod'};

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
    final usedNamesByFile = <String, Set<String>>{};

    final nonModuleDeclarationsByFile = <String, Set<String>>{};
    final classMembers = <ClassMemberDefinition>[];
    final topLevelDeclarations = <TopLevelDeclaration>[];

    for (final filePath in allFiles) {
      await _analyzeFile(
        filePath: filePath,
        groupsByBaseName: groupsByBaseName,
        filesWithModules: filesWithModules,
        usedNamesFromUserCode: usedNamesFromUserCode,
        usedNamesFromAllFiles: usedNamesFromAllFiles,
        usedNamesByFile: usedNamesByFile,
        nonModuleDeclarationsByFile: nonModuleDeclarationsByFile,
        classMembers: classMembers,
        topLevelDeclarations: topLevelDeclarations,
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
      usedNamesByFile: usedNamesByFile,
      filesWithModules: filesWithModules,
      allDartFiles: allFiles,
      nonModuleDeclarationsByFile: nonModuleDeclarationsByFile,
      classMembers: classMembers,
      topLevelDeclarations: topLevelDeclarations,
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
    required Map<String, Set<String>> usedNamesByFile,
    required Map<String, Set<String>> nonModuleDeclarationsByFile,
    required List<ClassMemberDefinition> classMembers,
    required List<TopLevelDeclaration> topLevelDeclarations,
  }) async {
    final parsed = await _parseCompilationUnit(filePath);
    if (parsed == null) return;

    final unit = parsed.unit;
    final fileContent = parsed.content;

    final isGenerated = isGeneratedFile(filePath);

    // 1) Collect used symbol names.
    final usedNamesInFile = _collectUsedNames(unit);
    usedNamesByFile[filePath] = usedNamesInFile;
    usedNamesFromAllFiles.addAll(usedNamesInFile);
    if (!isGenerated) usedNamesFromUserCode.addAll(usedNamesInFile);

    // 3) Collect module definitions and non-module top level declarations.
    final nonModuleNames = _collectDeclarationsAndModules(
      unit: unit,
      filePath: filePath,
      fileContent: fileContent,
      groupsByBaseName: groupsByBaseName,
      filesWithModules: filesWithModules,
      classMembers: classMembers,
      topLevelDeclarations: topLevelDeclarations,
    );

    if (nonModuleNames.isNotEmpty) {
      nonModuleDeclarationsByFile[filePath] = nonModuleNames;
    }
  }

  Future<_ParsedUnit?> _parseCompilationUnit(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final content = await file.readAsString();
    final parseResult = parseString(
      content: content,
      path: filePath,
      throwIfDiagnostics: false,
    );
    return _ParsedUnit(parseResult.unit, content);
  }

  Set<String> _collectUsedNames(CompilationUnit unit) {
    final names = <String>{};
    final visitor = UsedNamesVisitor(names);
    unit.accept(visitor);
    return names;
  }

  Set<String> _collectDeclarationsAndModules({
    required CompilationUnit unit,
    required String filePath,
    required String fileContent,
    required Map<String, List<ModuleDefinition>> groupsByBaseName,
    required Set<String> filesWithModules,
    required List<ClassMemberDefinition> classMembers,
    required List<TopLevelDeclaration> topLevelDeclarations,
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
          topLevelDeclarations: topLevelDeclarations,
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
          fileContent: fileContent,
          groupsByBaseName: groupsByBaseName,
          nonModuleNames: nonModuleNames,
          classMembers: classMembers,
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
    required List<TopLevelDeclaration> topLevelDeclarations,
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
        kind: ModuleDeclarationKind.riverpodFunction,
      );
      groupsByBaseName
          .putIfAbsent(name, () => <ModuleDefinition>[])
          .add(module);
    } else {
      nonModuleNames.add(name);
      topLevelDeclarations.add(
        TopLevelDeclaration(
          name: name,
          filePath: filePath,
          start: decl.offset,
          end: decl.end,
          kind: TopLevelDeclarationKind.function,
        ),
      );
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
          kind: ModuleDeclarationKind.providerVariable,
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
    required String fileContent,
    required Map<String, List<ModuleDefinition>> groupsByBaseName,
    required Set<String> nonModuleNames,
    required List<ClassMemberDefinition> classMembers,
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
        kind: ModuleDeclarationKind.providerClass,
      );
      groupsByBaseName
          .putIfAbsent(baseName, () => <ModuleDefinition>[])
          .add(module);
    } else {
      nonModuleNames.add(name);
      _collectClassMembers(
        decl: decl,
        filePath: filePath,
        fileContent: fileContent,
        classMembers: classMembers,
      );
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

  void _collectClassMembers({
    required ClassDeclaration decl,
    required String filePath,
    required String fileContent,
    required List<ClassMemberDefinition> classMembers,
  }) {
    for (final member in decl.members) {
      if (member is MethodDeclaration) {
        final name = member.name.lexeme;
        if (name.isEmpty || member.isOperator) continue;
        if (member.isAbstract || member.externalKeyword != null) continue;
        if (_implicitlyUsedMemberNames.contains(name)) continue;
        if (_hasOverrideAnnotation(member.metadata)) continue;

        classMembers.add(
          ClassMemberDefinition(
            className: decl.name.lexeme,
            name: name,
            filePath: filePath,
            start: member.offset,
            end: member.end,
            kind: _methodKind(member),
            isStatic: member.isStatic,
          ),
        );
      } else if (member is FieldDeclaration) {
        if (member.fields.variables.length != 1) continue;
        if (_hasOverrideAnnotation(member.metadata)) continue;

        final variable = member.fields.variables.single;
        final name = variable.name.lexeme;

        classMembers.add(
          ClassMemberDefinition(
            className: decl.name.lexeme,
            name: name,
            filePath: filePath,
            start: member.offset,
            end: member.end,
            kind: ClassMemberKind.field,
            isStatic: member.isStatic,
            extraRanges: _constructorRemovalsForField(decl, fileContent, name),
          ),
        );
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
    final isUsed = group.members.any(
      (member) => usedNamesFromUserCode.contains(member.name),
    );

    if (!isUsed) {
      unused.add(group);
    }
  }

  return unused;
}

bool _hasOverrideAnnotation(NodeList<Annotation> metadata) {
  for (final annotation in metadata) {
    final name = annotation.name;
    if (name is PrefixedIdentifier) {
      if (name.identifier.name == 'override') return true;
    } else if (name is SimpleIdentifier) {
      if (name.name == 'override') return true;
    }
  }
  return false;
}

ClassMemberKind _methodKind(MethodDeclaration member) {
  if (member.isGetter) return ClassMemberKind.getter;
  if (member.isSetter) return ClassMemberKind.setter;
  return ClassMemberKind.method;
}

List<OffsetRange> _constructorRemovalsForField(
  ClassDeclaration decl,
  String fileContent,
  String fieldName,
) {
  final removals = <OffsetRange>[];

  for (final member in decl.members) {
    if (member is! ConstructorDeclaration) continue;

    final paramsToRemove = <OffsetRange>[];
    var paramsMatchOnlyField = true;

    for (final param in member.parameters.parameters) {
      final paramName = _fieldFormalName(param);
      if (paramName == fieldName) {
        paramsToRemove.add(_expandCommaSeparatedRange(
          param.offset,
          param.end,
          fileContent,
        ));
      } else {
        paramsMatchOnlyField = false;
      }
    }

    final initializerRanges = <OffsetRange>[];
    var initializersMatchOnlyField = true;
    for (final initializer in member.initializers) {
      if (initializer is ConstructorFieldInitializer &&
          initializer.fieldName.name == fieldName) {
        initializerRanges.add(_expandCommaSeparatedRange(
          initializer.offset,
          initializer.end,
          fileContent,
        ));
      } else {
        initializersMatchOnlyField = false;
      }
    }

    final removesAllParams = paramsToRemove.isNotEmpty &&
        paramsToRemove.length == member.parameters.parameters.length;
    final removesAllInitializers = initializerRanges.isNotEmpty &&
        initializerRanges.length == member.initializers.length;
    final bodyIsEmpty = member.body is EmptyFunctionBody;

    if (removesAllParams &&
        (member.initializers.isEmpty || removesAllInitializers) &&
        bodyIsEmpty &&
        paramsMatchOnlyField &&
        initializersMatchOnlyField) {
      removals.add(OffsetRange(member.offset, member.end));
      continue;
    }

    if (paramsToRemove.isNotEmpty) {
      removals.addAll(paramsToRemove);
    }

    if (initializerRanges.isNotEmpty) {
      removals.addAll(_attachInitializerColon(
        constructor: member,
        ranges: initializerRanges,
        fileContent: fileContent,
        removesAllInitializers: removesAllInitializers,
      ));
    }
  }

  return removals;
}

String? _fieldFormalName(FormalParameter param) {
  if (param is FieldFormalParameter) {
    return param.name.lexeme;
  } else if (param is DefaultFormalParameter &&
      param.parameter is FieldFormalParameter) {
    return (param.parameter as FieldFormalParameter).name.lexeme;
  }
  return null;
}

List<OffsetRange> _attachInitializerColon({
  required ConstructorDeclaration constructor,
  required List<OffsetRange> ranges,
  required String fileContent,
  required bool removesAllInitializers,
}) {
  if (!removesAllInitializers || ranges.isEmpty) return ranges;

  final colonIndex = _findInitializerColonIndex(constructor, fileContent);
  if (colonIndex == null) return ranges;

  var newStart = colonIndex;
  while (newStart > 0 && _isWhitespace(fileContent.codeUnitAt(newStart - 1))) {
    newStart--;
  }

  final adjustedFirst = OffsetRange(newStart, ranges.first.end);

  return [adjustedFirst, ...ranges.skip(1)];
}

int? _findInitializerColonIndex(
  ConstructorDeclaration constructor,
  String fileContent,
) {
  if (constructor.initializers.isEmpty) return null;
  final searchStart = constructor.parameters.end;
  final firstInitializerOffset = constructor.initializers.first.offset;
  final colonIndex = fileContent.indexOf(':', searchStart);
  if (colonIndex == -1) return null;
  if (colonIndex > firstInitializerOffset) return null;
  return colonIndex;
}

OffsetRange _expandCommaSeparatedRange(
  int start,
  int end,
  String content,
) {
  var newStart = start;
  var newEnd = end;

  // Consume trailing whitespace and comma.
  var idx = newEnd;
  while (idx < content.length && _isWhitespace(content.codeUnitAt(idx))) {
    idx++;
  }
  if (idx < content.length && content[idx] == ',') {
    idx++;
    while (idx < content.length && _isWhitespace(content.codeUnitAt(idx))) {
      idx++;
    }
    newEnd = idx;
    return OffsetRange(newStart, newEnd);
  }

  // Otherwise, consume leading comma and whitespace.
  idx = newStart - 1;
  while (idx >= 0 && _isWhitespace(content.codeUnitAt(idx))) {
    idx--;
  }
  if (idx >= 0 && content[idx] == ',') {
    while (idx >= 1 && _isWhitespace(content.codeUnitAt(idx - 1))) {
      idx--;
    }
    newStart = idx;
  }

  return OffsetRange(newStart, newEnd);
}

bool _isWhitespace(int charCode) {
  const whitespaceCodes = [0x20, 0x09, 0x0a, 0x0d];
  return whitespaceCodes.contains(charCode);
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
  final usedNamesByFile = analysis.usedNamesByFile;

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

    // If any non-module declaration is used from another file (including
    // generated files), this file should not be deleted.
    final isUsedElsewhere =
        usedNamesByFile.entries.where((entry) => entry.key != filePath).any(
              (entry) => entry.value.any(declared.contains),
            );

    if (!isUsedElsewhere) {
      deletable.add(filePath);
    }
  }

  return deletable;
}

/// Apply in-place fixes to delete module definitions from files.
/// If a file becomes empty (only whitespace) after modifications,
/// it will be deleted.
void applyFixes(Map<String, List<ModuleDefinition>> modulesToDeleteByFile) {
  applyCombinedFixes(
    modulesToDeleteByFile: modulesToDeleteByFile,
    classMembersToDeleteByFile: const {},
    topLevelDeclarationsToDeleteByFile: const {},
    updateLabel: 'modules',
  );
}

/// Apply in-place fixes to delete unused class members.
void applyClassMemberFixes(
  Map<String, List<ClassMemberDefinition>> membersToDeleteByFile,
) {
  applyCombinedFixes(
    modulesToDeleteByFile: const {},
    classMembersToDeleteByFile: membersToDeleteByFile,
    topLevelDeclarationsToDeleteByFile: const {},
    updateLabel: 'class members',
  );
}

/// Apply in-place fixes to delete both modules and class members.
/// Set [deleteEmptyFiles] to false to retain files that become empty.
void applyCombinedFixes({
  required Map<String, List<ModuleDefinition>> modulesToDeleteByFile,
  required Map<String, List<ClassMemberDefinition>> classMembersToDeleteByFile,
  required Map<String, List<TopLevelDeclaration>>
      topLevelDeclarationsToDeleteByFile,
  String updateLabel = 'code',
  bool deleteEmptyFiles = true,
  void Function(String message)? onFileChange,
}) {
  final allFiles = <String>{
    ...modulesToDeleteByFile.keys,
    ...classMembersToDeleteByFile.keys,
    ...topLevelDeclarationsToDeleteByFile.keys,
  };

  for (final filePath in allFiles) {
    final file = File(filePath);
    if (!file.existsSync()) continue;

    final removals = <_TextRemoval>[
      ...?modulesToDeleteByFile[filePath]
          ?.map((module) => _TextRemoval(module.start, module.end)),
      ...?classMembersToDeleteByFile[filePath]?.expand(
        (member) => [
          _TextRemoval(member.start, member.end),
          ...member.extraRanges
              .map((range) => _TextRemoval(range.start, range.end)),
        ],
      ),
      ...?topLevelDeclarationsToDeleteByFile[filePath]
          ?.map((decl) => _TextRemoval(decl.start, decl.end)),
    ];

    if (removals.isEmpty) continue;

    var content = file.readAsStringSync();
    content = _applyTextRemovals(content, removals);

    final log = onFileChange ?? print;

    if (content.trim().isEmpty) {
      if (deleteEmptyFiles) {
        file.deleteSync();
        log('Deleted file: $filePath');
      } else {
        file.writeAsStringSync(content);
        log('Updated file ($updateLabel): $filePath');
      }
    } else {
      file.writeAsStringSync(content);
      log('Updated file ($updateLabel): $filePath');
    }
  }
}

String _applyTextRemovals(String content, List<_TextRemoval> removals) {
  if (removals.isEmpty) return content;

  final sorted = removals.toList()
    ..sort((a, b) => b.start.compareTo(a.start)); // Delete from bottom

  var updated = content;
  for (final removal in sorted) {
    updated = updated.replaceRange(removal.start, removal.end, '');
    updated = _collapseWhitespaceAroundRemoval(updated, removal.start);
  }

  return updated;
}

String _collapseWhitespaceAroundRemoval(String content, int pivot) {
  if (content.isEmpty) return content;

  final clampedPivot =
      pivot < 0 ? 0 : (pivot > content.length ? content.length : pivot);

  final left = _previousNonWhitespace(content, clampedPivot);
  final right = _nextNonWhitespace(content, clampedPivot);
  if (right == null) return content;

  final regionStart = (left ?? -1) + 1;
  final regionEnd = right;
  final region = content.substring(regionStart, regionEnd);
  final newlineCount = '\n'.allMatches(region).length;

  if (newlineCount < 3) return content;

  final indentStart = _indentStart(content, right);
  final indent = content.substring(indentStart, right);

  return content.replaceRange(regionStart, regionEnd, '\n\n$indent');
}

int? _previousNonWhitespace(String content, int start) {
  var idx = start - 1;
  while (idx >= 0) {
    if (!_isWhitespace(content.codeUnitAt(idx))) return idx;
    idx--;
  }
  return null;
}

int? _nextNonWhitespace(String content, int start) {
  var idx = start;
  while (idx < content.length) {
    if (!_isWhitespace(content.codeUnitAt(idx))) return idx;
    idx++;
  }
  return null;
}

int _indentStart(String content, int nonWhitespaceIndex) {
  var idx = nonWhitespaceIndex;
  while (idx > 0) {
    final char = content.codeUnitAt(idx - 1);
    if (char == 0x0a || char == 0x0d) break;
    if (!_isWhitespace(char)) break;
    idx--;
  }
  return idx;
}

class _TextRemoval {
  final int start;
  final int end;

  _TextRemoval(this.start, this.end);
}

/// Compute unused class members (methods/getters/setters).
///
/// This uses names from all files, including generated ones, to avoid deleting
/// members that are referenced indirectly via generated code.
List<ClassMemberDefinition> computeUnusedClassMembers(
  List<ClassMemberDefinition> classMembers,
  Set<String> usedNamesFromAllFiles,
) {
  final unused = <ClassMemberDefinition>[];

  for (final member in classMembers) {
    if (!usedNamesFromAllFiles.contains(member.name)) {
      unused.add(member);
    }
  }

  return unused;
}

/// Compute unused top-level declarations such as free functions.
List<TopLevelDeclaration> computeUnusedTopLevelDeclarations(
  List<TopLevelDeclaration> declarations,
  Set<String> usedNamesFromAllFiles,
) {
  final unused = <TopLevelDeclaration>[];

  for (final declaration in declarations) {
    if (declaration.name == 'main') {
      // Preserve executable entrypoints even if they are not referenced.
      continue;
    }
    if (!usedNamesFromAllFiles.contains(declaration.name)) {
      unused.add(declaration);
    }
  }

  return unused;
}

class _ParsedUnit {
  final CompilationUnit unit;
  final String content;

  _ParsedUnit(this.unit, this.content);
}
