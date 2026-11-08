import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fzu_assistant/service/paper_library_service.dart';

void main() {
  late Directory base;
  late PaperLibraryService library;
  setUp(() async {
    base = await Directory.systemTemp.createTemp('paper-library-test-');
    library = PaperLibraryService(directory: () async => base);
  });
  tearDown(() async => base.delete(recursive: true));
  Future<File> file(String relative, {String data = 'pdf'}) async {
    final result = File('${base.path}/$relative');
    await result.parent.create(recursive: true);
    return result.writeAsString(data);
  }

  test('不存在的下载目录为空且不创建目录', () async {
    expect(await library.list(), isEmpty);
    expect(await Directory('${base.path}/paper_downloads').exists(), isFalse);
  });
  test('已发布目录允许 .part 文件名，在途目录始终隐藏', () async {
    await file('paper_downloads/saved-paper-complete/download.part');
    await file('paper_downloads/pending-paper-active/file.pdf');
    final saved = (await library.list()).single;
    expect(saved.name, 'download.part');
    expect((await library.validate(saved)).path, saved.file.path);
    await library.delete(saved);
    expect(await saved.file.exists(), isFalse);
    expect(
      await File('${base.path}/paper_downloads/pending-paper-active/file.pdf')
          .exists(),
      isTrue,
    );
  });
  test('读取旧下载、排除半成品、空文件和无关目录，保留同名文件', () async {
    await file('paper_downloads/paper-one/数学.pdf');
    await file('paper_downloads/paper-two/数学.pdf');
    await file('paper_downloads/paper-active/数学.pdf.part');
    await file('paper_downloads/paper-empty/empty.pdf', data: '');
    await file('paper_downloads/other/private.pdf');
    final papers = await library.list();
    expect(papers.length, 2);
    expect(papers.map((p) => p.name), everyElement('数学.pdf'));
    expect(papers.fold<int>(0, (total, p) => total + p.bytes), 6);
  });
  test('删除仅移除选择的文件和空目录，保留其他文件', () async {
    await file('paper_downloads/paper-one/one.pdf');
    final other = await file('paper_downloads/paper-two/two.pdf');
    final selected = (await library.list()).firstWhere(
      (p) => p.name == 'one.pdf',
    );
    await library.delete(selected);
    expect(await selected.file.exists(), isFalse);
    expect(await selected.file.parent.exists(), isFalse);
    expect(await other.exists(), isTrue);
  });
  test('伪造外部路径和已消失文件不能打开或删除', () async {
    final outside = await file('outside/secret.pdf');
    final forged = LocalPaper(outside, 'secret.pdf', 3, DateTime.now());
    await expectLater(
      library.delete(forged),
      throwsA(isA<FileSystemException>()),
    );
    expect(await outside.exists(), isTrue);
    await file('paper_downloads/paper-one/one.pdf');
    final selected = (await library.list()).single;
    await selected.file.delete();
    await expectLater(
      library.validate(selected),
      throwsA(isA<FileSystemException>()),
    );
  });
  test('半成品不能通过伪造条目删除', () async {
    final partial = await file('paper_downloads/paper-active/file.part');
    await expectLater(
      library.delete(LocalPaper(partial, 'file.part', 3, DateTime.now())),
      throwsA(isA<FileSystemException>()),
    );
    expect(await partial.exists(), isTrue);
  });
}
