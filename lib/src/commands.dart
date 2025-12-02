import 'dart:io';

import 'analyzer.dart';
import 'models.dart';
import 'removal_targets.dart';
import 'utils.dart';

/// Entry point for `analyze` command.
Future<void> runAnalyzeCommand(String rootPath) async {
  print('Analyzing project under: $rootPath');

  final analysis = await analyzeProject(rootPath);

  final unusedClassMembers = computeUnusedClassMembers(
    analysis.classMembers,
    analysis.usedNamesFromAllFiles,
  );
  final unusedTopLevel = computeUnusedTopLevelDeclarations(
    analysis.topLevelDeclarations,
    analysis.usedNamesFromAllFiles,
  );

  if (unusedClassMembers.isNotEmpty) {
    print('=== Unused class members ===');
    for (final member in unusedClassMembers) {
      if (isGeneratedFile(member.filePath)) continue;
      print('- ${member.className}.${member.name} (${member.filePath})');
    }
  } else {
    print('No unused class members found.');
  }

  if (unusedTopLevel.isNotEmpty) {
    if (unusedClassMembers.isNotEmpty) {
      print('');
    }
    print('=== Unused top-level declarations ===');
    for (final decl in unusedTopLevel) {
      if (isGeneratedFile(decl.filePath)) continue;
      print('- $decl');
    }
  } else {
    print('No unused top-level declarations found.');
  }

  final unusedGroups = computeUnusedGroups(
    analysis.groupsByBaseName,
    analysis.usedNamesFromUserCode,
  );

  if ((unusedClassMembers.isNotEmpty || unusedTopLevel.isNotEmpty) &&
      unusedGroups.isNotEmpty) {
    print('');
  }

  if (unusedGroups.isEmpty) {
    print('No unused modules found.');
  } else {
    print('=== Unused modules ===');
    for (final group in unusedGroups) {
      print('- Base name: ${group.baseName}');
      for (final module in group.members) {
        // Do not touch generated files like *.g.dart / *.freezed.dart.
        if (isGeneratedFile(module.filePath)) {
          continue;
        }
        print('    - $module');
      }
    }
  }

  final deletableFiles = computeDeletableNonModuleFiles(analysis).toList()
    ..sort();

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
/// Removes unused declarations matching [removalTargets] and deletes empty
/// module files when file removals are enabled.
Future<void> runFixCommand(
  String rootPath, {
  RemovalTargets removalTargets = const RemovalTargets.all(),
}) async {
  print('Analyzing project under: $rootPath');

  var iteration = 1;
  var hasAppliedFix = false;
  final changeLogs = <String>[];

  while (true) {
    final analysis = await analyzeProject(rootPath);

    final unusedClassMembers = computeUnusedClassMembers(
      analysis.classMembers,
      analysis.usedNamesFromAllFiles,
    );

    final unusedGroups = computeUnusedGroups(
      analysis.groupsByBaseName,
      analysis.usedNamesFromUserCode,
    );
    final unusedTopLevel = computeUnusedTopLevelDeclarations(
      analysis.topLevelDeclarations,
      analysis.usedNamesFromAllFiles,
    );

    final modulesToDeleteByFile = <String, List<ModuleDefinition>>{};
    final classMembersToDeleteByFile = <String, List<ClassMemberDefinition>>{};
    final topLevelToDeleteByFile = <String, List<TopLevelDeclaration>>{};

    for (final group in unusedGroups) {
      for (final module in group.members) {
        // Do not touch generated files like *.g.dart / *.freezed.dart.
        if (isGeneratedFile(module.filePath)) continue;
        if (!removalTargets.allowModule(module)) continue;

        modulesToDeleteByFile
            .putIfAbsent(module.filePath, () => <ModuleDefinition>[])
            .add(module);
      }
    }

    for (final member in unusedClassMembers) {
      // Do not touch generated files like *.g.dart / *.freezed.dart.
      if (isGeneratedFile(member.filePath)) continue;
      if (!removalTargets.allowClassMember(member)) continue;

      classMembersToDeleteByFile
          .putIfAbsent(member.filePath, () => <ClassMemberDefinition>[])
          .add(member);
    }

    for (final declaration in unusedTopLevel) {
      if (isGeneratedFile(declaration.filePath)) continue;
      if (!removalTargets.allowTopLevel(declaration)) continue;
      topLevelToDeleteByFile
          .putIfAbsent(declaration.filePath, () => <TopLevelDeclaration>[])
          .add(declaration);
    }

    final deletableFiles = removalTargets.removeFiles
        ? (computeDeletableNonModuleFiles(analysis).toList()..sort())
        : <String>[];

    final nothingToDelete = modulesToDeleteByFile.isEmpty &&
        classMembersToDeleteByFile.isEmpty &&
        topLevelToDeleteByFile.isEmpty &&
        deletableFiles.isEmpty;

    if (nothingToDelete) {
      if (!hasAppliedFix) {
        print(
            'No unused declarations matched the remove options. Nothing to fix.');
      }
      break;
    }

    print('Iteration $iteration: applying deletions...');

    if (modulesToDeleteByFile.isNotEmpty ||
        classMembersToDeleteByFile.isNotEmpty ||
        topLevelToDeleteByFile.isNotEmpty) {
      applyCombinedFixes(
        modulesToDeleteByFile: modulesToDeleteByFile,
        classMembersToDeleteByFile: classMembersToDeleteByFile,
        topLevelDeclarationsToDeleteByFile: topLevelToDeleteByFile,
        updateLabel: 'modules/class members/top-level',
        deleteEmptyFiles: removalTargets.removeFiles,
        onFileChange: changeLogs.add,
      );
      hasAppliedFix = true;
    }

    if (removalTargets.removeFiles) {
      for (final filePath in deletableFiles) {
        final file = File(filePath);
        if (file.existsSync()) {
          file.deleteSync();
          hasAppliedFix = true;
          changeLogs.add('Deleted file: $filePath');
        }
      }
    }

    iteration++;
  }

  if (changeLogs.isNotEmpty) {
    print('\nChanges applied:');
    for (final log in changeLogs) {
      print(log);
    }
  }

  print('Fix completed.');
}
