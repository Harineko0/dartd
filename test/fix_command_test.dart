import 'dart:io';

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
}
