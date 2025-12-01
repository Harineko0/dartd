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

  if (unusedClassMembers.isEmpty) {
    print('No unused class members found.');
  } else {
    print('=== Unused class members ===');
    for (final member in unusedClassMembers) {
      if (isGeneratedFile(member.filePath)) continue;
      print('- ${member.className}.${member.name} (${member.filePath})');
    }
  }

  final unusedGroups = computeUnusedGroups(
    analysis.groupsByBaseName,
    analysis.usedNamesFromUserCode,
  );

  if (unusedClassMembers.isNotEmpty && unusedGroups.isNotEmpty) {
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

    final modulesToDeleteByFile = <String, List<ModuleDefinition>>{};
    final classMembersToDeleteByFile = <String, List<ClassMemberDefinition>>{};

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

    final deletableFiles = removalTargets.removeFiles
        ? (computeDeletableNonModuleFiles(analysis).toList()..sort())
        : <String>[];

    final nothingToDelete = modulesToDeleteByFile.isEmpty &&
        classMembersToDeleteByFile.isEmpty &&
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
        classMembersToDeleteByFile.isNotEmpty) {
      applyCombinedFixes(
        modulesToDeleteByFile: modulesToDeleteByFile,
        classMembersToDeleteByFile: classMembersToDeleteByFile,
        updateLabel: 'modules/class members',
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
