import 'dart:io';

import 'package:dartd/src/analyzer.dart';
import 'package:dartd/src/models.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('removes unused class methods while keeping used ones', () async {
    final tempDir = Directory.systemTemp.createTempSync('dartd_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
    final file = File(p.join(libDir.path, 'foo.dart'));

    file.writeAsStringSync('''
class Foo {
  void usedMethod() {}

  void unusedMethod() {}

  String get unusedGetter => 'x';

  int _internalUnused() => 1;

  String unusedField = 'unused';

  final int keptByConstructor;

  Foo(this.keptByConstructor);
}

void runFoo() {
  Foo().usedMethod();
}
''');

    final analysis = await analyzeProject(libDir.path);

    final unused = computeUnusedClassMembers(
      analysis.classMembers,
      analysis.usedNamesFromAllFiles,
    );

    expect(
      unused.map((m) => m.name),
      containsAll(
        ['unusedMethod', 'unusedGetter', '_internalUnused', 'unusedField'],
      ),
    );
    expect(unused.map((m) => m.name), isNot(contains('usedMethod')));
    expect(unused.map((m) => m.name), isNot(contains('keptByConstructor')));

    final membersToDeleteByFile = <String, List<ClassMemberDefinition>>{};
    for (final member in unused) {
      membersToDeleteByFile
          .putIfAbsent(member.filePath, () => <ClassMemberDefinition>[])
          .add(member);
    }

    applyClassMemberFixes(membersToDeleteByFile);

    final updatedContent = file.readAsStringSync();
    expect(updatedContent, contains('usedMethod'));
    expect(updatedContent, isNot(contains('unusedMethod')));
    expect(updatedContent, isNot(contains('unusedGetter')));
    expect(updatedContent, isNot(contains('_internalUnused')));
    expect(updatedContent, isNot(contains('unusedField')));
    expect(updatedContent, contains('keptByConstructor'));
  });
}
