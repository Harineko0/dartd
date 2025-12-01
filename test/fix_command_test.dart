import 'dart:io';

import 'package:dartd/src/analyzer.dart';
import 'package:dartd/src/models.dart';
import 'package:dartd/src/commands.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('fix deletes cascading unused providers in a single run', () async {
    final tempDir = Directory.systemTemp.createTempSync('dartd_fix_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
    final aFile = File(p.join(libDir.path, 'a.dart'));
    final bFile = File(p.join(libDir.path, 'b.dart'));
    final cFile = File(p.join(libDir.path, 'c.dart'));

    aFile.writeAsStringSync('''
import 'b.dart';

final aProvider = bProvider;
''');

    bFile.writeAsStringSync('''
import 'c.dart';

final bProvider = cProvider;
''');

    cFile.writeAsStringSync('''
final cProvider = 0;
''');

    await runFixCommand(libDir.path);

    expect(aFile.existsSync(), isFalse);
    expect(bFile.existsSync(), isFalse);
    expect(cFile.existsSync(), isFalse);
  });

  test('fix does not leave extra blank lines after module removal', () {
    final tempDir = Directory.systemTemp.createTempSync('dartd_fix_spacing_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
    final file = File(p.join(libDir.path, 'spacing.dart'));

    file.writeAsStringSync('''
import 'package:riverpod_annotation/riverpod_annotation.dart';

class Something {}

@riverpod
int foo(FooRef ref) => 0;

@riverpod
int bar(BarRef ref) => 1;
''');

    final content = file.readAsStringSync();
    final start = content.indexOf('@riverpod');
    final end = content.indexOf(';', start) + 1;

    final module = ModuleDefinition(
      baseName: 'foo',
      name: 'foo',
      filePath: file.path,
      start: start,
      end: end,
      isProvider: false,
      isRiverpod: true,
    );

    applyFixes({
      file.path: [module]
    });

    final updated = file.readAsStringSync();
    expect(updated, isNot(contains('\n\n\n')));
    expect(updated, contains('class Something {}\n\n@riverpod'));
    expect(updated, contains('@riverpod\nint bar'));
  });
}
