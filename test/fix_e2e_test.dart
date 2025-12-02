import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final projectRoot = Directory.current.path;

  group('dartd fix e2e', () {
    test(
      'removes unused provider even when base name is used elsewhere',
      () async {
        final programDir = await _copyProgramToTemp('provider_masked_by_model', projectRoot);

        final result = await _runFix(projectRoot, programDir);
        _expectSuccess(result);

        final providerFile = File(p.join(programDir.path, 'lib', 'user_provider.dart'));
        expect(
          providerFile.existsSync(),
          isFalse,
          reason: _cliDebug(result),
        );
      },
    );

    test(
      'removes unused class while keeping used class',
      () async {
        final programDir = await _copyProgramToTemp('unused_class', projectRoot);

        final result = await _runFix(projectRoot, programDir);
        _expectSuccess(result);

        // confirm that the file containing the unused class is deleted
        final exceptionFile = File(p.join(programDir.path, 'lib', 'exception.dart'));
        final isFileExist = exceptionFile.existsSync();
        final isFileContainsUnusedClass = isFileExist && exceptionFile.readAsStringSync().contains('class UnusedClass');

        expect(isFileExist, isTrue, reason: _cliDebug(result));
        expect(isFileContainsUnusedClass, isFalse, reason: _cliDebug(result));
      },
    );

    test('removes unused class members and preserves used ones', () async {
      final programDir = await _copyProgramToTemp('unused_member', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final serviceFile = File(p.join(programDir.path, 'lib', 'service.dart'));
      expect(serviceFile.existsSync(), isTrue, reason: _cliDebug(result));

      final content = serviceFile.readAsStringSync();
      expect(content, contains('used()'));
      expect(
        content,
        isNot(contains('unusedHelper')),
        reason: _cliDebug(result),
      );
    });

    test('deletes files that only contain unused helpers', () async {
      final programDir = await _copyProgramToTemp('unused_helpers', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final helperFile = File(p.join(programDir.path, 'lib', 'helpers.dart'));
      expect(helperFile.existsSync(), isFalse, reason: _cliDebug(result));

      final mainFile = File(p.join(programDir.path, 'lib', 'main.dart'));
      expect(mainFile.existsSync(), isTrue, reason: _cliDebug(result));
    });

    test('deletes unused extension files', () async {
      final programDir = await _copyProgramToTemp('extension_unused', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final extFile = File(p.join(programDir.path, 'lib', 'extension.dart'));
      expect(extFile.existsSync(), isFalse, reason: _cliDebug(result));
    });

    test('deletes unused class with only a constructor', () async {
      final programDir = await _copyProgramToTemp('class_constructor_unused', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final file = File(p.join(programDir.path, 'lib', 'foo.dart'));
      expect(file.existsSync(), isFalse, reason: _cliDebug(result));
    });

    test('deletes unused class with named parameter constructor', () async {
      final programDir = await _copyProgramToTemp('named_constructor_unused', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final file = File(p.join(programDir.path, 'lib', 'config.dart'));
      expect(file.existsSync(), isFalse, reason: _cliDebug(result));
    });

    test('removes unused getter/setter members', () async {
      final programDir = await _copyProgramToTemp('getter_setter_unused', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final file = File(p.join(programDir.path, 'lib', 'counter.dart'));
      expect(file.existsSync(), isTrue, reason: _cliDebug(result));

      final content = file.readAsStringSync();
      expect(content, isNot(contains('get value')), reason: _cliDebug(result));
      expect(content, isNot(contains('set value')), reason: _cliDebug(result));
      expect(content, isNot(contains('_value')), reason: _cliDebug(result));
      expect(content, contains('use()'), reason: _cliDebug(result));
    });

    test('removes unused riverpod modules', () async {
      final programDir = await _copyProgramToTemp('riverpod_unused', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final file = File(p.join(programDir.path, 'lib', 'providers.dart'));
      expect(file.existsSync(), isFalse, reason: _cliDebug(result));
    });

    test('deletes unused generic function definitions', () async {
      final programDir = await _copyProgramToTemp('generic_function_unused', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final file = File(p.join(programDir.path, 'lib', 'ok.dart'));
      expect(file.existsSync(), isFalse, reason: _cliDebug(result));
    });

    test('deletes unused generic extensions', () async {
      final programDir = await _copyProgramToTemp('generic_extension_unused', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final file = File(p.join(programDir.path, 'lib', 'result.dart'));
      expect(file.existsSync(), isFalse, reason: _cliDebug(result));
    });

    test('deletes unused function with named parameters', () async {
      final programDir = await _copyProgramToTemp('named_param_function_unused', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final file = File(p.join(programDir.path, 'lib', 'api.dart'));
      expect(file.existsSync(), isFalse, reason: _cliDebug(result));
    });

    test('deletes unused subclass with named ctor and super.key', () async {
      final programDir = await _copyProgramToTemp('subclass_named_ctor_unused', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final file = File(p.join(programDir.path, 'lib', 'add_playlist_bottom_sheet.dart'));
      expect(file.existsSync(), isFalse, reason: _cliDebug(result));
    });

    test('deletes unused abstract generic interfaces', () async {
      final programDir = await _copyProgramToTemp('abstract_generic_unused', projectRoot);

      final result = await _runFix(projectRoot, programDir);
      _expectSuccess(result);

      final file = File(p.join(programDir.path, 'lib', 'partial_updater.dart'));
      expect(file.existsSync(), isFalse, reason: _cliDebug(result));
    });
  });
}

Future<Directory> _copyProgramToTemp(
  String name,
  String projectRoot,
) async {
  final sourceDir = Directory(p.join(projectRoot, 'test', 'prog', name));
  expect(sourceDir.existsSync(), isTrue, reason: 'Missing program fixture $name');

  final targetDir = await Directory.systemTemp.createTemp('dartd_prog_$name');
  await _copyDirectory(sourceDir, targetDir);

  return targetDir;
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final relative = p.relative(entity.path, from: source.path);
    final destPath = p.join(target.path, relative);

    if (entity is Directory) {
      await Directory(destPath).create(recursive: true);
    } else if (entity is File) {
      await Directory(p.dirname(destPath)).create(recursive: true);
      await entity.copy(destPath);
    }
  }
}

Future<ProcessResult> _runFix(
  String projectRoot,
  Directory programDir,
) {
  final rootPath = p.join(programDir.path, 'lib');

  return Process.run(
    'dart',
    [
      'run',
      p.join(projectRoot, 'bin', 'dartd.dart'),
      'fix',
      '--root',
      rootPath,
    ],
    workingDirectory: projectRoot,
  );
}

void _expectSuccess(ProcessResult result) {
  expect(
    result.exitCode,
    0,
    reason: _cliDebug(result),
  );
}

String _cliDebug(ProcessResult result) {
  return [
    'exitCode: ${result.exitCode}',
    'stdout:',
    '${result.stdout}',
    'stderr:',
    '${result.stderr}',
  ].join('\n');
}
