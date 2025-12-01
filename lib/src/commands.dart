import 'dart:io';

import 'analyzer.dart';
import 'models.dart';
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
/// Removes unused modules and deletes empty module files.
Future<void> runFixCommand(String rootPath) async {
  print('Analyzing project under: $rootPath');

  final analysis = await analyzeProject(rootPath);

  final unusedClassMembers = computeUnusedClassMembers(
    analysis.classMembers,
    analysis.usedNamesFromAllFiles,
  );

  final unusedGroups = computeUnusedGroups(
    analysis.groupsByBaseName,
    analysis.usedNamesFromUserCode,
  );

  if (unusedGroups.isEmpty && unusedClassMembers.isEmpty) {
    print('No unused modules or class members found. Nothing to fix.');
  } else {
    print('Removing unused code...');
    final modulesToDeleteByFile = <String, List<ModuleDefinition>>{};
    final classMembersToDeleteByFile = <String, List<ClassMemberDefinition>>{};

    for (final group in unusedGroups) {
      for (final module in group.members) {
        // Do not touch generated files like *.g.dart / *.freezed.dart.
        if (isGeneratedFile(module.filePath)) {
          continue;
        }

        modulesToDeleteByFile
            .putIfAbsent(module.filePath, () => <ModuleDefinition>[])
            .add(module);
      }
    }

    for (final member in unusedClassMembers) {
      // Do not touch generated files like *.g.dart / *.freezed.dart.
      if (isGeneratedFile(member.filePath)) {
        continue;
      }

      classMembersToDeleteByFile
          .putIfAbsent(member.filePath, () => <ClassMemberDefinition>[])
          .add(member);
    }

    applyCombinedFixes(
      modulesToDeleteByFile: modulesToDeleteByFile,
      classMembersToDeleteByFile: classMembersToDeleteByFile,
      updateLabel: 'modules/class members',
    );
  }

  // Delete files with no used module/non-module definitions.
  final deletableFiles = computeDeletableNonModuleFiles(analysis).toList()
    ..sort();

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
