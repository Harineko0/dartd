import 'dart:io';

class ParsedClass {
  ParsedClass({
    required this.name,
    required this.filePath,
    required this.start,
    required this.end,
  });

  final String name;
  final String filePath; // relative to project root
  final int start;
  final int end;

  Map<String, Object> toJson() => {
        'name': name,
        'file': filePath,
        'start': start,
        'end': end,
      };
}

class AnalysisReport {
  AnalysisReport({
    required this.rootPath,
    required this.unusedClasses,
    required this.unusedModules,
    required this.fileContents,
  });

  final String rootPath;
  final List<ParsedClass> unusedClasses;
  final List<String> unusedModules; // relative to project root
  final Map<String, String> fileContents; // key is relative path

  Map<String, Object> toJson() => {
        'unusedClasses': unusedClasses.map((c) => c.toJson()).toList(),
        'unusedModules': unusedModules,
      };
}

class FixOutcome {
  FixOutcome({required this.modifiedFiles, required this.deletedModules});

  final List<String> modifiedFiles;
  final List<String> deletedModules;
}

class UnusedScanner {
  UnusedScanner({required String rootPath, String? packageName})
      : rootPath = Directory(rootPath).absolute.path,
        packageName = packageName;

  final String rootPath;
  final String? packageName;

  static const _ignoredDirs = {
    '.git',
    '.dart_tool',
    'build',
    '.fvm',
    '.kiri',
  };

  static const _generatedSuffixes = {
    '.g.dart',
    '.freezed.dart',
    '.gen.dart',
    '.gr.dart',
  };

  Future<AnalysisReport> analyze() async {
    final files = _collectDartFiles();
    final fileContents = <String, String>{};
    final classes = <ParsedClass>[];

    for (final file in files) {
      final relPath = _relativePath(file.path);
      final content = await file.readAsString();
      fileContents[relPath] = content;
      if (_isGenerated(relPath)) continue;
      classes.addAll(_parseClasses(relPath, content));
    }

    final unusedClasses = _findUnusedClasses(classes, fileContents);
    final unusedModules = _findUnusedModules(fileContents);

    return AnalysisReport(
      rootPath: rootPath,
      unusedClasses: unusedClasses,
      unusedModules: unusedModules,
      fileContents: fileContents,
    );
  }

  Future<FixOutcome> applyFixes(AnalysisReport report,
      {bool dryRun = false}) async {
    final grouped = <String, List<ParsedClass>>{};
    for (final klass in report.unusedClasses) {
      grouped.putIfAbsent(klass.filePath, () => []).add(klass);
    }

    final modifiedFiles = <String>[];
    for (final entry in grouped.entries) {
      final filePath = entry.key;
      final content = report.fileContents[filePath]!;
      final updated = _stripRanges(
        content,
        entry.value..sort((a, b) => b.start.compareTo(a.start)),
      );
      if (!dryRun) {
        final target = File(_absolutePath(filePath));
        await target.writeAsString(updated);
      }
      modifiedFiles.add(filePath);
    }

    final deletedModules = <String>[];
    for (final module in report.unusedModules) {
      if (!dryRun) {
        final file = File(_absolutePath(module));
        if (await file.exists()) {
          await file.delete();
        }
      }
      deletedModules.add(module);
    }

    return FixOutcome(
      modifiedFiles: modifiedFiles,
      deletedModules: deletedModules,
    );
  }

  List<File> _collectDartFiles() {
    final rootDir = Directory(rootPath);
    final files = <File>[];
    final toVisit = <Directory>[rootDir];

    while (toVisit.isNotEmpty) {
      final current = toVisit.removeLast();
      for (final entity in current.listSync(followLinks: false)) {
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';
        if (entity is Directory) {
          if (_ignoredDirs.contains(name)) {
            continue;
          }
          toVisit.add(entity);
        } else if (entity is File && entity.path.endsWith('.dart')) {
          files.add(entity);
        }
      }
    }

    return files;
  }

  List<ParsedClass> _parseClasses(String filePath, String content) {
    final result = <ParsedClass>[];
    final regex = RegExp(r'class\s+([A-Za-z0-9_]+)[^{]*{');
    for (final match in regex.allMatches(content)) {
      final name = match.group(1);
      if (name == null) continue;
      final braceIndex = content.indexOf('{', match.end - 1);
      if (braceIndex == -1) continue;

      int braceDepth = 0;
      int endIndex = -1;
      for (int i = braceIndex; i < content.length; i++) {
        final char = content[i];
        if (char == '{') {
          braceDepth++;
        } else if (char == '}') {
          braceDepth--;
          if (braceDepth == 0) {
            endIndex = i + 1;
            break;
          }
        }
      }
      if (endIndex == -1) continue;

      int startIndex = match.start;
      final newLineBefore =
          startIndex > 0 ? content.lastIndexOf('\n', startIndex - 1) : -1;
      if (newLineBefore != -1) {
        startIndex = newLineBefore + 1;
      }
      while (startIndex > 0 &&
          (content[startIndex - 1] == '\n' ||
              content[startIndex - 1] == '\r')) {
        startIndex--;
      }

      var trailingIndex = endIndex;
      while (trailingIndex < content.length &&
          (content[trailingIndex] == '\n' ||
              content[trailingIndex] == '\r' ||
              content[trailingIndex] == ' ' ||
              content[trailingIndex] == '\t')) {
        trailingIndex++;
      }

      result.add(ParsedClass(
        name: name,
        filePath: filePath,
        start: startIndex,
        end: trailingIndex,
      ));
    }
    return result;
  }

  List<ParsedClass> _findUnusedClasses(
    List<ParsedClass> classes,
    Map<String, String> fileContents,
  ) {
    final unused = <ParsedClass>[];
    final names = <String, List<ParsedClass>>{};
    for (final klass in classes) {
      names.putIfAbsent(klass.name, () => []).add(klass);
    }

    for (final entry in names.entries) {
      final name = entry.key;
      final decls = entry.value;
      final regex = RegExp('\\b${RegExp.escape(name)}\\b');
      var count = 0;
      for (final content in fileContents.values) {
        count += regex.allMatches(content).length;
      }
      if (count <= decls.length) {
        unused.addAll(decls);
      }
    }
    return unused;
  }

  List<String> _findUnusedModules(Map<String, String> fileContents) {
    final pkgName = packageName ?? _readPackageName();
    final libPrefix =
        '$rootPath${Platform.pathSeparator}lib${Platform.pathSeparator}';
    final candidates = <String>{};
    for (final path in fileContents.keys) {
      if (_isGenerated(path)) continue;
      final absolute = _absolutePath(path);
      if (absolute.startsWith(libPrefix)) {
        candidates.add(_relativeLibPath(absolute, libPrefix));
      }
    }

    final usedModules = <String>{};
    final directive = RegExp("(?:import|export|part)\\s+['\"]([^'\"]+)['\"]");

    for (final entry in fileContents.entries) {
      final importerAbs = _absolutePath(entry.key);
      for (final match in directive.allMatches(entry.value)) {
        final target = match.group(1);
        if (target == null) continue;
        final resolved =
            _resolveImport(importerAbs, target, pkgName, libPrefix);
        if (resolved != null) {
          usedModules.add(resolved);
        }
      }
    }

    final mainLibrary = pkgName != null ? '$pkgName.dart' : null;
    final unused = candidates.where((module) {
      if (mainLibrary != null && module == mainLibrary) return false;
      return !usedModules.contains(module);
    }).toList()
      ..sort();
    return unused;
  }

  String _stripRanges(String content, List<ParsedClass> classes) {
    var updated = content;
    for (final klass in classes) {
      updated = updated.replaceRange(klass.start, klass.end, '');
    }
    return updated;
  }

  String _relativePath(String absolutePath) {
    final normalizedRoot = rootPath.endsWith(Platform.pathSeparator)
        ? rootPath
        : '$rootPath${Platform.pathSeparator}';
    if (absolutePath.startsWith(normalizedRoot)) {
      final slice = absolutePath.substring(normalizedRoot.length);
      return slice.replaceAll(Platform.pathSeparator, '/');
    }
    return absolutePath.replaceAll(Platform.pathSeparator, '/');
  }

  String _absolutePath(String relativePath) {
    final cleaned = relativePath.replaceAll('/', Platform.pathSeparator);
    return '$rootPath${Platform.pathSeparator}$cleaned';
  }

  String _relativeLibPath(String absolutePath, String libPrefix) {
    var rel = absolutePath.substring(libPrefix.length);
    rel = rel.replaceAll(Platform.pathSeparator, '/');
    return rel;
  }

  String? _resolveImport(
    String importerAbs,
    String target,
    String? pkgName,
    String libPrefix,
  ) {
    final uri = Uri.parse(target);
    if (uri.scheme == 'package' && pkgName != null) {
      if (uri.pathSegments.isEmpty) return null;
      if (uri.pathSegments.first != pkgName) return null;
      final remaining = uri.pathSegments.skip(1).join('/');
      return remaining;
    }
    if (uri.scheme.isEmpty) {
      final importerUri = Uri.file(importerAbs);
      final resolvedPath = importerUri.resolveUri(uri).toFilePath();
      if (resolvedPath.startsWith(libPrefix)) {
        return _relativeLibPath(resolvedPath, libPrefix);
      }
    }
    return null;
  }

  String? _readPackageName() {
    final file = File('$rootPath${Platform.pathSeparator}pubspec.yaml');
    if (!file.existsSync()) return null;
    try {
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.startsWith('name:')) {
          final parts = trimmed.split(':');
          if (parts.length >= 2) {
            final name = parts.sublist(1).join(':').trim();
            if (name.isNotEmpty) return name;
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _isGenerated(String relativePath) {
    final lower = relativePath.toLowerCase();
    for (final suffix in _generatedSuffixes) {
      if (lower.endsWith(suffix)) return true;
    }
    return false;
  }
}
