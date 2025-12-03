#!/usr/bin/env dart

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:dartd/src/commands.dart';
import 'package:dartd/src/removal_targets.dart';

const int _exitCodeUsage = 64;
const _removeOptionNames = [
  'all',
  'file',
  'class',
  'function',
  'var',
  'method',
  'member',
  'import',
];

Future<void> main(List<String> args) async {
  final code = await _runCli(args);
  exit(code);
}

Future<int> _runCli(List<String> args) async {
  final parser = _buildArgParser();

  ArgResults results;
  try {
    results = parser.parse(args);
  } on ArgParserException catch (e) {
    stderr.writeln(e.message);
    _printUsage(parser);
    return _exitCodeUsage;
  }

  if (results['help'] == true || results.command == null) {
    _printUsage(parser);
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
      await runAnalyzeCommand(rootPath);
      return 0;
    case 'fix':
      final removalTargets = RemovalTargets.fromNames(
        (command['remove'] as List<Object?>?)?.cast<String>() ?? const ['all'],
      );
      final iterationOption = command['iteration'] as String?;
      final maxIterations =
          iterationOption == null ? null : int.tryParse(iterationOption);

      if (iterationOption != null &&
          (maxIterations == null || maxIterations < 1)) {
        stderr.writeln('Iteration must be a positive integer.');
        return _exitCodeUsage;
      }

      await runFixCommand(
        rootPath,
        removalTargets: removalTargets,
        maxIterations: maxIterations,
      );
      return 0;
    default:
      stderr.writeln('Unknown command: ${command.name}');
      _printUsage(parser);
      return _exitCodeUsage;
  }
}

ArgParser _buildArgParser() {
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
    )
    ..addOption(
      'iteration',
      valueHelp: 'count',
      help: 'Maximum number of fix iterations to perform.',
    )
    ..addMultiOption(
      'remove',
      defaultsTo: const ['all'],
      allowed: _removeOptionNames,
      help:
          'Kinds of unused declarations to remove (file, class, function, var, method, member, import, all).',
      allowedHelp: const {
        'all': 'Remove all supported unused declarations.',
        'file': 'Delete empty Dart files with no used declarations.',
        'class': 'Remove unused class-based modules (e.g. *Provider classes).',
        'function': 'Remove unused annotated module functions.',
        'var': 'Remove unused module/provider variables.',
        'method': 'Remove unused class methods/getters/setters.',
        'member': 'Remove unused class members (fields, methods, accessors).',
        'import': 'Remove unused import directives.',
      },
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

void _printUsage(ArgParser parser) {
  print('''
dartd - A tool to analyze and remove unused Dart declarations.

Usage:
  dartd analyze --root lib
  dartd fix --root lib [--iteration count] [--remove all|file|class|function|var|method|member]

Commands:
  analyze   Analyze unused declarations.
  fix       Remove unused declarations (configurable via --remove).

Options:
${parser.usage}
''');
}
