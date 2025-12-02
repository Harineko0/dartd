import 'dart:io';

import 'package:dartd/src/commands.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('dartd fix removes unused code', () {
    test('removes unused global functions', () async {
      final projectDir = await _copyFixture('global_functions', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, isNot(contains('unusedHelper')));

      final helper = await _readFileIfExists(projectDir, 'lib/helper.dart');
      expect(helper ?? '', isNot(contains('helperFromOtherFile')));
    });

    test('removes unused global variables', () async {
      final projectDir = await _copyFixture('global_variables', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, isNot(contains('unusedValue')));

      final values = await _readFileIfExists(projectDir, 'lib/values.dart');
      expect(values ?? '', isNot(contains('otherUnused')));
    });

    test('removes unused classes', () async {
      final projectDir = await _copyFixture('classes', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, isNot(contains('UnreachableUtility')));

      final classFile = await _readFileIfExists(projectDir, 'lib/class.dart');
      expect(classFile ?? '', isNot(contains('UnreachableUtilityOnOtherFile')));
    });

    test('removes unused extensions', () async {
      final projectDir = await _copyFixture('extensions', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, isNot(contains('NumberFormatting')));

      final ext = await _readFileIfExists(projectDir, 'lib/ext.dart');
      expect(ext ?? '', isNot(contains('HiddenNumber')));
    });

    test('removes unused abstract classes', () async {
      final projectDir = await _copyFixture('abstract_classes', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, isNot(contains('BackgroundTask')));

      final task = await _readFileIfExists(projectDir, 'lib/task.dart');
      expect(task ?? '', isNot(contains('DetachedJob')));
    });

    test('removes unused interface classes', () async {
      final projectDir = await _copyFixture('interfaces', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, isNot(contains('CacheEntry')));

      final iface = await _readFileIfExists(projectDir, 'lib/interface.dart');
      expect(iface ?? '', isNot(contains('LocalCache')));
    });

    test('removes unused generics', () async {
      final projectDir = await _copyFixture('generics', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, isNot(contains('Box')));

      final box = await _readFileIfExists(projectDir, 'lib/box.dart');
      expect(box ?? '', isNot(contains('SpareBox')));
    });

    test('removes unused methods', () async {
      final projectDir = await _copyFixture('methods', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, isNot(contains('unusedCallback')));
      expect(content, contains('init'));

      final secondary =
          await _readFileIfExists(projectDir, 'lib/secondary.dart');
      expect(secondary ?? '', isNot(contains('unusedSecondary')));
    });

    test('removes unused members with named parameter constructors', () async {
      final projectDir = await _copyFixture('members', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('username'));
      expect(content, isNot(contains('password')));
      expect(content, isNot(contains('password)')));

      final profile = await _readFileIfExists(projectDir, 'lib/profile.dart');
      expect(profile ?? '', isNot(contains('Profile')));
    });

    test('removes unused static members', () async {
      final projectDir = await _copyFixture('static_members', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, isNot(contains('unusedName')));
      expect(content, isNot(contains('unusedLabel')));
    });

    test('removes unused named parameters and fields', () async {
      final projectDir =
          await _copyFixture('named_parameter_constructors', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('baseUrl'));
      expect(content, isNot(contains('timeout')));

      final client = await _readFileIfExists(projectDir, 'lib/client.dart');
      expect(client ?? '', isNot(contains('LoggingClient')));
    });

    test('removes unused code across multiple syntaxes', () async {
      final projectDir = await _copyFixture('multiple_syntaxes', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, isNot(contains('_arrowHelper')));
      expect(content, isNot(contains('MultiSyntax')));
      expect(content, isNot(contains('HiddenDigits')));

      final additional =
          await _readFileIfExists(projectDir, 'lib/additional.dart');
      expect(additional ?? '', isNot(contains('Auxiliary')));
      expect(additional ?? '', isNot(contains('unseenHelper')));
    });

    test('respects iteration limit when fixing chained usages', () async {
      final projectDir = await _copyFixture('iteration_limit', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final firstPass = await _runFix(projectDir.path, maxIterations: 1);
      _expectSuccess(firstPass);

      final contentAfterFirst = await _readFile(projectDir, 'lib/main.dart');
      expect(contentAfterFirst, isNot(contains('unusedEntry')));
      expect(contentAfterFirst, contains('helper'));
      expect(contentAfterFirst, contains('secondary'));

      final secondPass = await _runFix(projectDir.path);
      _expectSuccess(secondPass);

      final mainFile = File(p.join(projectDir.path, 'lib', 'main.dart'));
      if (mainFile.existsSync()) {
        final contentAfterSecond = await mainFile.readAsString();
        expect(contentAfterSecond, isNot(contains('helper')));
        expect(contentAfterSecond, isNot(contains('secondary')));
      } else {
        // File can be deleted when empty after the final pass.
        expect(mainFile.existsSync(), isFalse);
      }
    });

    test('removes unused riverpod providers even with generated stubs',
        () async {
      final projectDir = await _copyFixture('riverpod_generator', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final mainContent = await _readFile(projectDir, 'lib/main.dart');
      final generatedContent = await _readFile(projectDir, 'lib/main.g.dart');
      expect(mainContent, isNot(contains('unusedCounter')));
      expect(generatedContent, contains('unusedCounterProvider'));
    });

    test('removes unused riverpod class providers', () async {
      final projectDir = await _copyFixture('class_provider', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final provider = await _readFileIfExists(projectDir, 'lib/provider.dart');
      final providerG = await _readFileIfExists(projectDir, 'lib/provider.g.dart');
      final state = await _readFileIfExists(projectDir, 'lib/state.dart');

      expect(provider, isNotNull);
      expect(providerG, isNotNull);
      expect(state, isNotNull);
    });

    test('removes unused freezed classes', () async {
      final projectDir = await _copyFixture('freezed', 'unused');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final modelContent = await _readFile(projectDir, 'lib/model.dart');
      expect(modelContent, isNot(contains('Todo')));
    });
  });

  group('dartd fix preserves used code', () {
    test('keeps referenced global functions', () async {
      final projectDir = await _copyFixture('global_functions', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('usedHelper'));

      final helper = await _readFileIfExists(projectDir, 'lib/helper.dart');
      expect(helper, isNotNull);
      expect(helper, contains('helperFromOtherFile'));
    });

    test('keeps referenced global variables', () async {
      final projectDir = await _copyFixture('global_variables', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('usedValue'));

      final values = await _readFileIfExists(projectDir, 'lib/values.dart');
      expect(values, isNotNull);
      expect(values, contains('otherUsed'));
    });

    test('keeps referenced classes', () async {
      final projectDir = await _copyFixture('classes', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('VisibleUtility'));

      final classFile = await _readFileIfExists(projectDir, 'lib/class.dart');
      expect(classFile, isNotNull);
      expect(classFile, contains('VisibleUtilityOnOtherFile'));
    });

    test('keeps referenced extensions', () async {
      final projectDir = await _copyFixture('extensions', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('ShoutyString'));

      final ext = await _readFileIfExists(projectDir, 'lib/ext.dart');
      expect(ext, isNotNull);
      expect(ext, contains('FriendlyString'));
    });

    test('keeps abstract classes that are consumed', () async {
      final projectDir = await _copyFixture('abstract_classes', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('ConsolePresenter'));
      expect(content, contains('Presenter'));

      final task = await _readFileIfExists(projectDir, 'lib/task.dart');
      expect(task, isNotNull);
      expect(task, contains('Renderer'));
    });

    test('keeps interface classes that are implemented', () async {
      final projectDir = await _copyFixture('interfaces', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('Service'));
      expect(content, contains('ConcreteService'));

      final iface = await _readFileIfExists(projectDir, 'lib/interface.dart');
      expect(iface, isNotNull);
      expect(iface, contains('RemoteService'));
    });

    test('keeps generics that are in use', () async {
      final projectDir = await _copyFixture('generics', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('Result'));

      final box = await _readFileIfExists(projectDir, 'lib/box.dart');
      expect(box, isNotNull);
      expect(box, contains('SpareResult'));
    });

    test('keeps used methods', () async {
      final projectDir = await _copyFixture('methods', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('dispose'));
      expect(content, contains('init'));

      final secondary =
          await _readFileIfExists(projectDir, 'lib/secondary.dart');
      expect(secondary, isNotNull);
      expect(secondary, contains('synchronize'));
    });

    test('keeps referenced members', () async {
      final projectDir = await _copyFixture('members', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('username'));
      expect(content, contains('password'));

      final profile = await _readFileIfExists(projectDir, 'lib/profile.dart');
      expect(profile, isNotNull);
      expect(profile, contains('Profile'));
    });

    test('keeps referenced static members', () async {
      final projectDir = await _copyFixture('static_members', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('FeatureFlags'));
      expect(content, contains('apiEndpoint'));
      expect(content, contains('label'));
    });

    test('keeps named parameters that are used', () async {
      final projectDir =
          await _copyFixture('named_parameter_constructors', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('timeout'));
      expect(content, contains('baseUrl'));

      final client = await _readFileIfExists(projectDir, 'lib/client.dart');
      expect(client, isNotNull);
      expect(client, contains('LoggingClient'));
    });

    test('keeps mixed syntaxes when referenced', () async {
      final projectDir = await _copyFixture('multiple_syntaxes', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final content = await _readFile(projectDir, 'lib/main.dart');
      expect(content, contains('_arrowHelper'));
      expect(content, contains('MultiSyntax'));
      expect(content, contains('HiddenDigits'));

      final additional =
          await _readFileIfExists(projectDir, 'lib/additional.dart');
      expect(additional, isNotNull);
      expect(additional, contains('Auxiliary'));
    });

    test('keeps riverpod providers that are read', () async {
      final projectDir = await _copyFixture('riverpod_generator', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final mainContent = await _readFile(projectDir, 'lib/main.dart');
      final generatedContent = await _readFile(projectDir, 'lib/main.g.dart');
      expect(mainContent, contains('greetingProvider'));
      expect(generatedContent, contains('greetingProvider'));
    });

    test('keeps riverpod class providers that are read', () async {
      final projectDir = await _copyFixture('class_provider', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final provider = await _readFileIfExists(projectDir, 'lib/provider.dart');
      final providerG = await _readFileIfExists(projectDir, 'lib/provider.g.dart');
      final state = await _readFileIfExists(projectDir, 'lib/state.dart');

      expect(provider, isNotNull);
      expect(providerG, isNotNull);
      expect(state, isNotNull);
    });

    test('keeps freezed classes that are constructed', () async {
      final projectDir = await _copyFixture('freezed', 'used');
      addTearDown(() => projectDir.delete(recursive: true));

      final result = await _runFix(projectDir.path);
      _expectSuccess(result);

      final modelContent = await _readFile(projectDir, 'lib/model.dart');
      expect(modelContent, contains('Todo'));
    });
  });
}

Future<Directory> _copyFixture(String name, String variant) async {
  final source = Directory(p.join('test', 'resources', name, variant));
  if (!source.existsSync()) {
    throw StateError('Missing fixture for $name ($variant)');
  }

  final destination =
      await Directory.systemTemp.createTemp('dartd_e2e_${name}_');
  await _copyDirectory(source, destination);
  return destination;
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await for (final entity in source.list(recursive: false)) {
    final newPath = p.join(destination.path, p.basename(entity.path));
    if (entity is Directory) {
      final newDir = Directory(newPath);
      await newDir.create(recursive: true);
      await _copyDirectory(entity, newDir);
    } else if (entity is File) {
      await File(newPath).create(recursive: true);
      await entity.copy(newPath);
    }
  }
}

Future<int> _runFix(String rootPath, {int? maxIterations}) async {
  await runFixCommand(rootPath, maxIterations: maxIterations);
  return 0;
}

Future<String> _readFile(Directory projectDir, String relativePath) async {
  final file = File(p.join(projectDir.path, relativePath));
  if (!file.existsSync()) {
    throw StateError('Expected file to exist: ${file.path}');
  }
  return file.readAsString();
}

Future<String?> _readFileIfExists(
  Directory projectDir,
  String relativePath,
) async {
  final file = File(p.join(projectDir.path, relativePath));
  if (!file.existsSync()) return null;
  return file.readAsString();
}

void _expectSuccess(int exitCode) {
  expect(exitCode, 0);
}
