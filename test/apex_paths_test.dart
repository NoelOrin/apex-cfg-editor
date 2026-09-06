import 'dart:io';
import 'package:apex_cfg_editor/core/paths/apex_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('paths'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('finds videoconfig under Documents/Respawn/Apex/local', () {
    final f = File('${tmp.path}/Documents/Respawn/Apex/local/videoconfig.txt')
      ..createSync(recursive: true);
    final r = ApexPathFinder(homeDir: tmp.path).findVideoconfig();
    expect(r, f.path);
  });

  test('finds autoexec.cfg via steam libraryfolders.vdf (app 1172470)', () {
    final cfg = File(
        '${tmp.path}/Steam/steamapps/common/Apex Legends/global/cfg/autoexec.cfg')
      ..createSync(recursive: true);
    File('${tmp.path}/Steam/steamapps/libraryfolders.vdf').writeAsStringSync('''
"libraryfolders"
{
  "0" { "path" "${tmp.path}/Steam" }
  "1" { "path" "${tmp.path}/Steam" }
}
''');
    final r = ApexPathFinder(homeDir: tmp.path).findAutoexec();
    expect(r, cfg.path);
  });

  test('missing → null (UI falls back to manual picker)', () {
    expect(ApexPathFinder(homeDir: tmp.path).findVideoconfig(), isNull);
  });

  test('finds autoexec in a secondary steam library listed in vdf', () {
    Directory('${tmp.path}/SteamLibraryA/steamapps/common')
        .createSync(recursive: true);
    final cfg = File(
        '${tmp.path}/SteamLibraryB/steamapps/common/Apex Legends/global/cfg/autoexec.cfg')
      ..createSync(recursive: true);
    Directory('${tmp.path}/Steam/steamapps').createSync(recursive: true);
    File('${tmp.path}/Steam/steamapps/libraryfolders.vdf').writeAsStringSync('''
"libraryfolders"
{
  "0" { "path" "${tmp.path}/SteamLibraryA" }
  "1" { "path" "${tmp.path}/SteamLibraryB" }
}
''');
    final r = ApexPathFinder(homeDir: tmp.path).findAutoexec();
    expect(r, cfg.path);
  });

  test('unescapes vdf windows backslash escapes (\\\\) to forward slashes',
      () {
    final cfg = File(
        '${tmp.path}/SteamLib/steamapps/common/Apex Legends/global/cfg/autoexec.cfg')
      ..createSync(recursive: true);
    Directory('${tmp.path}/Steam/steamapps').createSync(recursive: true);
    File('${tmp.path}/Steam/steamapps/libraryfolders.vdf').writeAsStringSync(
        '"libraryfolders"\n{\n  "0" { "path" "${tmp.path}\\\\SteamLib" }\n}\n');
    final r = ApexPathFinder(homeDir: tmp.path).findAutoexec();
    expect(r, cfg.path);
  });
}
