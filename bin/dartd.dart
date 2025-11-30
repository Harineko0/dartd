#!/usr/bin/env dart

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:dartd/src/commands.dart';

const int _exitCodeUsage = 64;

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
      await runFixCommand(rootPath);
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
Flutter unused module cleaner

Usage:
  dartd analyze --root lib
  dartd fix --root lib

Commands:
  analyze   Analyze unused riverpod modules.
  fix       Remove unused riverpod modules and empty module files.

Options:
${parser.usage}
''');
}
