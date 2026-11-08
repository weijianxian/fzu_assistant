import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fzu_assistant/model/feature_access.dart';
import 'package:fzu_assistant/service/api/paper_service.dart';
import 'package:path_provider/path_provider.dart';

enum PaperDownloadFailure {
  accessDenied,
  cancelled,
  invalidFile,
  incomplete,
  cleanupFailed,
  failed,
}

class PaperDownloadException implements Exception {
  const PaperDownloadException(this.failure);

  final PaperDownloadFailure failure;

  @override
  String toString() => switch (failure) {
    PaperDownloadFailure.accessDenied => '请先在第三方服务设置中允许历年卷',
    PaperDownloadFailure.cancelled => '下载已取消',
    PaperDownloadFailure.invalidFile => '试卷路径或文件名无效',
    PaperDownloadFailure.incomplete => '文件不完整，请重新下载',
    PaperDownloadFailure.cleanupFailed => '无法清理未完成的试卷文件',
    PaperDownloadFailure.failed => '试卷下载失败',
  };
}

class PaperDownloadProgress {
  const PaperDownloadProgress({required this.received, this.total});

  final int received;
  final int? total;

  double? get fraction =>
      total != null && total! > 0 ? (received / total!).clamp(0.0, 1.0) : null;
}

class PaperDownloadedFile {
  const PaperDownloadedFile({
    required this.file,
    required this.name,
    required this.bytes,
  });

  final File file;
  final String name;
  final int bytes;
}

class _PaperDownloadOperation {
  _PaperDownloadOperation(this.generation, this.token) {
    token.whenCancel.then((_) => stopTransfers());
  }

  final int generation;
  final CancelToken token;
  final _transfers = <CancelToken>{};

  CancelToken startTransfer() {
    final transfer = CancelToken();
    _transfers.add(transfer);
    if (token.isCancelled) stopTransfers();
    return transfer;
  }

  void stopTransfer(CancelToken transfer) {
    _transfers.remove(transfer);
    if (!transfer.isCancelled) {
      transfer.cancel(token.cancelError?.error);
    }
  }

  void stopTransfers() {
    for (final transfer in _transfers.toList()) {
      stopTransfer(transfer);
    }
  }

  void cancel(PaperDownloadFailure failure) {
    if (!token.isCancelled) {
      token.cancel(PaperDownloadException(failure));
    }
    stopTransfers();
  }
}

/// Downloads public papers into an app-owned, unique directory.
///
/// This client deliberately has no academic/SSO interceptors or cookie storage.
/// Each operation observes consent changes, including allow → hide → allow.
class PaperDownloadService extends ChangeNotifier {
  PaperDownloadService({
    required this.access,
    required this._api,
    Dio? dio,
    Future<Directory> Function()? directory,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 30),
               followRedirects: false,
             ),
           ),
       _ownsDio = dio == null,
       _directory = directory ?? getApplicationSupportDirectory {
    access.addListener(_accessChanged);
  }

  final ValueListenable<FeatureAccess> access;
  final PaperService _api;
  final Dio _dio;
  final bool _ownsDio;
  final Future<Directory> Function() _directory;
  final _operations = <_PaperDownloadOperation>{};
  int _generation = 0;
  bool _closed = false;

  bool get isClosed => _closed;

  void _accessChanged() {
    if (access.value == FeatureAccess.allow) return;
    _generation++;
    for (final operation in _operations.toList()) {
      operation.cancel(PaperDownloadFailure.accessDenied);
    }
  }

  _PaperDownloadOperation _begin(CancelToken? cancelToken) {
    final operation = _PaperDownloadOperation(
      _generation,
      cancelToken ?? CancelToken(),
    );
    _check(operation);
    _operations.add(operation);
    return operation;
  }

  void _check(_PaperDownloadOperation operation) {
    if (access.value != FeatureAccess.allow ||
        operation.generation != _generation) {
      throw const PaperDownloadException(PaperDownloadFailure.accessDenied);
    }
    if (_closed || operation.token.isCancelled) {
      final reason = operation.token.cancelError?.error;
      throw reason is PaperDownloadException
          ? reason
          : const PaperDownloadException(PaperDownloadFailure.cancelled);
    }
  }

  Future<T> _whileActive<T>(
    Future<T> future,
    _PaperDownloadOperation operation,
  ) => Future.any([
    future,
    operation.token.whenCancel.then<T>((_) {
      _check(operation);
      throw const PaperDownloadException(PaperDownloadFailure.cancelled);
    }),
  ]);

  static void validateFileName(String name) {
    PaperService.childPath('/', name);
    if (name.trim() != name ||
        name.endsWith('.') ||
        name.contains(RegExp(r'[<>:"|?*\x00-\x1f\x7f-\x9f]')) ||
        utf8.encode(name).length > 240 ||
        RegExp(
          r'^(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:[ .]|$)',
          caseSensitive: false,
        ).hasMatch(name)) {
      throw const FormatException('试卷文件名无效');
    }
  }

  static Uri _validateUrl(Uri uri) {
    if (!{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const PaperDownloadException(PaperDownloadFailure.invalidFile);
    }
    return uri;
  }

  Future<Uri> _resolve(String path, _PaperDownloadOperation operation) async {
    _check(operation);
    final normalized = PaperService.normalizePath(path);
    if (normalized == '/') {
      throw const PaperDownloadException(PaperDownloadFailure.invalidFile);
    }
    validateFileName(normalized.split('/').last);
    final uri = await _whileActive(_api.download(normalized), operation);
    _check(operation);
    return _validateUrl(uri);
  }

  /// Browser and clipboard actions also request a fresh, dynamic download URL.
  Future<Uri> resolveUrl(String path, {CancelToken? cancelToken}) async {
    final operation = _begin(cancelToken);
    try {
      return await _resolve(path, operation);
    } on PaperDownloadException {
      rethrow;
    } on FormatException {
      throw const PaperDownloadException(PaperDownloadFailure.invalidFile);
    } catch (_) {
      _check(operation);
      throw const PaperDownloadException(PaperDownloadFailure.failed);
    } finally {
      _operations.remove(operation);
    }
  }

  Future<Response<ResponseBody>> _response(
    Uri uri,
    _PaperDownloadOperation operation,
  ) async {
    // Follow only validated HTTP(S) redirects, never native/file protocols.
    for (var redirects = 0; redirects <= 5; redirects++) {
      _check(operation);
      final transfer = operation.startTransfer();
      final response = await _dio.getUri<ResponseBody>(
        _validateUrl(uri),
        cancelToken: transfer,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (status) =>
              status == 200 || {301, 302, 303, 307, 308}.contains(status),
        ),
      );
      if (response.statusCode == 200) return response;
      // Cancelling only Dio's exposed stream does not stop its source stream.
      // Stop this hop without cancelling the operation or the next hop.
      operation.stopTransfer(transfer);
      await response.data?.stream
          .listen((_) {}, onError: (Object _) {})
          .cancel();
      _check(operation);
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || redirects == 5) {
        throw const PaperDownloadException(PaperDownloadFailure.failed);
      }
      uri = _validateUrl(uri.resolve(location));
    }
    throw const PaperDownloadException(PaperDownloadFailure.failed);
  }

  Future<PaperDownloadedFile> download({
    required String path,
    required String name,
    CancelToken? cancelToken,
    ValueChanged<PaperDownloadProgress>? onProgress,
  }) async {
    final operation = _begin(cancelToken);
    Directory? ownedDirectory;
    File? partial;
    File? completed;
    RandomAccessFile? output;
    StreamIterator<List<int>>? stream;
    var succeeded = false;
    try {
      validateFileName(name);
      final normalized = PaperService.normalizePath(path);
      if (normalized.split('/').last != name) {
        throw const PaperDownloadException(PaperDownloadFailure.invalidFile);
      }
      final uri = await _resolve(normalized, operation);
      _check(operation);
      final base = await _whileActive(_directory(), operation);
      _check(operation);
      final root = Directory(
        '${base.absolute.path}${Platform.pathSeparator}paper_downloads',
      );
      final rootType = await FileSystemEntity.type(
        root.path,
        followLinks: false,
      );
      if (rootType != FileSystemEntityType.notFound &&
          rootType != FileSystemEntityType.directory) {
        throw const PaperDownloadException(PaperDownloadFailure.invalidFile);
      }
      await root.create(recursive: true);
      _check(operation);
      // A unique owned directory avoids collisions and overwriting user files.
      ownedDirectory = await root.createTemp('pending-paper-');
      _check(operation);
      partial = File(
        '${ownedDirectory.path}${Platform.pathSeparator}$name.part',
      );
      output = await partial.open(mode: FileMode.writeOnly);
      _check(operation);
      onProgress?.call(const PaperDownloadProgress(received: 0));
      _check(operation);
      final response = await _response(uri, operation);
      _check(operation);
      final body = response.data;
      if (body == null) {
        throw const PaperDownloadException(PaperDownloadFailure.incomplete);
      }
      // Encoded response sizes can describe compressed rather than local bytes.
      final length =
          response.headers.value(HttpHeaders.contentEncodingHeader) == null
          ? int.tryParse(
              response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
            )
          : null;
      final total = length != null && length > 0 ? length : null;
      var received = 0;
      stream = StreamIterator(body.stream);
      while (await _whileActive(stream.moveNext(), operation)) {
        _check(operation);
        final bytes = stream.current;
        await output.writeFrom(bytes);
        _check(operation);
        received += bytes.length;
        onProgress?.call(
          PaperDownloadProgress(received: received, total: total),
        );
        _check(operation);
      }
      await stream.cancel();
      stream = null;
      await output.flush();
      await output.close();
      output = null;
      _check(operation);
      if (received == 0 || (total != null && received != total)) {
        throw const PaperDownloadException(PaperDownloadFailure.incomplete);
      }
      final target = File(
        '${ownedDirectory.path}${Platform.pathSeparator}$name',
      );
      if (await target.exists()) {
        throw const PaperDownloadException(PaperDownloadFailure.failed);
      }
      _check(operation);
      completed = await partial.rename(target.path);
      _check(operation);
      // Publish the whole directory atomically. A completed filename may itself
      // end in ".part", so file extensions cannot identify download state.
      final folderName = ownedDirectory.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .last;
      ownedDirectory = await ownedDirectory.rename(
        '${root.path}${Platform.pathSeparator}saved-${folderName.substring(8)}',
      );
      completed = File('${ownedDirectory.path}${Platform.pathSeparator}$name');
      partial = null;
      _check(operation);
      final result = PaperDownloadedFile(
        file: completed,
        name: name,
        bytes: received,
      );
      succeeded = true;
      return result;
    } on PaperDownloadException {
      rethrow;
    } on FormatException {
      throw const PaperDownloadException(PaperDownloadFailure.invalidFile);
    } catch (_) {
      _check(operation);
      throw const PaperDownloadException(PaperDownloadFailure.failed);
    } finally {
      operation.stopTransfers();
      _operations.remove(operation);
      if (!succeeded) {
        try {
          await stream?.cancel();
        } finally {
          try {
            await output?.close();
          } finally {
            if (ownedDirectory != null) {
              try {
                if (partial != null && await partial.exists()) {
                  await partial.delete();
                }
                if (completed != null && await completed.exists()) {
                  await completed.delete();
                }
                // Delete this operation's files and then its empty directory.
                await ownedDirectory.delete();
              } catch (_) {
                throw const PaperDownloadException(
                  PaperDownloadFailure.cleanupFailed,
                );
              }
            }
          }
        }
      }
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    access.removeListener(_accessChanged);
    for (final operation in _operations.toList()) {
      operation.cancel(PaperDownloadFailure.cancelled);
    }
    notifyListeners();
    if (_ownsDio) _dio.close(force: true);
    super.dispose();
  }
}
