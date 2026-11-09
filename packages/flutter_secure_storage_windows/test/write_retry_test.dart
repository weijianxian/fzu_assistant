import 'dart:io';

import 'package:flutter_secure_storage_windows/src/flutter_secure_storage_windows_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('access denied fails without retrying forever', () async {
    var writes = 0;
    await expectLater(
      writeWithBoundedRetry(() async {
        writes++;
        throw const FileSystemException(
          'Access denied',
          'credentials.dat',
          OSError('Access denied', 5),
        );
      }),
      throwsA(isA<FileSystemException>()),
    );
    expect(writes, 1);
  });

  test('transient sharing failure retries a bounded number of times', () async {
    var writes = 0;
    await writeWithBoundedRetry(
      () async {
        if (++writes < 3) {
          throw const FileSystemException(
            'Sharing violation',
            'credentials.dat',
            OSError('Sharing violation', 32),
          );
        }
      },
      wait: () async {},
    );
    expect(writes, 3);

    writes = 0;
    await expectLater(
      writeWithBoundedRetry(
        () async {
          writes++;
          throw const FileSystemException(
            'Sharing violation',
            'credentials.dat',
            OSError('Sharing violation', 32),
          );
        },
        wait: () async {},
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(writes, 3);
  });
}
