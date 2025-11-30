import 'dart:convert';
import 'dart:io';

import 'package:dartd/src/unused_scanner.dart';

Future<void> main(List<String> args) async {
  final cli = _Cli();
  final code = await cli.run(args);
  exit(code);
}

class _Cli {
  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
      _printUsage();
      return 64;
    }

    final command = args.first;
    late final Map<String, String> options;
    try {
      options = _parseOptions(args.skip(1).toList());
    } on FormatException catch (error) {
      stderr.writeln('${error.message}\n');
      _printUsage();
      return 64;
    }
    final root = options['root'] ?? Directory.current.path;
    final asJson = options['json'] == 'true';
    final dryRun = options['dryRun'] == 'true';

    final scanner = UnusedScanner(rootPath: root);

    switch (command) {
      case 'analyze':
        return _runAnalyze(scanner, asJson);
      case 'fix':
        return _runFix(scanner, dryRun);
      default:
        stderr.writeln('Unknown command: $command\n');
        _printUsage();
        return 64;
    }
  }

  Map<String, String> _parseOptions(List<String> args) {
    final options = <String, String>{};

    for (int i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case '--root':
        case '-r':
          if (i + 1 >= args.length) {
            throw FormatException('Missing value for $arg');
          }
          options['root'] = args[++i];
          break;
        case '--json':
          options['json'] = 'true';
          break;
        case '--dry-run':
          options['dryRun'] = 'true';
          break;
        default:
          throw FormatException('Unknown option: $arg');
      }
    }

    return options;
  }

  Future<int> _runAnalyze(UnusedScanner scanner, bool asJson) async {
    final report = await scanner.analyze();
    if (asJson) {
      final encoder = JsonEncoder.withIndent('  ');
      stdout.writeln(encoder.convert(report.toJson()));
    } else {
      stdout.writeln('Unused classes: ${report.unusedClasses.length}');
      for (final klass in report.unusedClasses) {
        stdout.writeln('  • ${klass.name} (${klass.filePath})');
      }
      stdout.writeln('Unused modules (lib/): ${report.unusedModules.length}');
      for (final module in report.unusedModules) {
        stdout.writeln('  • lib/$module');
      }
      stdout.writeln(
        '\nHeuristic detection only. Review before applying fixes.',
      );
    }
    return 0;
  }

  Future<int> _runFix(UnusedScanner scanner, bool dryRun) async {
    final report = await scanner.analyze();
    final outcome = await scanner.applyFixes(report, dryRun: dryRun);

    stdout.writeln(
      dryRun ? 'Dry run: no files modified.' : 'Applied fixes for unused code.',
    );
    stdout.writeln('Modified files: ${outcome.modifiedFiles.length}');
    for (final file in outcome.modifiedFiles) {
      stdout.writeln('  • $file');
    }
    stdout.writeln('Deleted modules: ${outcome.deletedModules.length}');
    for (final module in outcome.deletedModules) {
      stdout.writeln('  • lib/$module');
    }
    return 0;
  }

  void _printUsage() {
    stdout.writeln('''
dartd - detect and prune unused Dart classes or modules.

Usage:
  dart run bin/dartd.dart analyze [--root <path>] [--json]
  dart run bin/dartd.dart fix [--root <path>] [--dry-run]

Options:
  -r, --root     Project root to scan (default: current directory)
      --json     Emit analysis as JSON
      --dry-run  Show what would be removed without writing files
  -h, --help     Show this message
''');
  }
}
