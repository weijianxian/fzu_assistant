import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:fzu_assistant/service/paper_download_service.dart';

class LocalPaper {
  const LocalPaper(this.file, this.name, this.bytes, this.modified);
  final File file;
  final String name;
  final int bytes;
  final DateTime modified;
}

/// Local-only access to completed downloads. Never follows symbolic links.
class PaperLibraryService {
  PaperLibraryService({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;

  Future<Directory> _root() async {
    final base = await _directory();
    return Directory(
      '${base.absolute.path}${Platform.pathSeparator}paper_downloads',
    );
  }

  Future<bool> _regularDirectory(Directory directory) async =>
      await FileSystemEntity.type(directory.path, followLinks: false) ==
      FileSystemEntityType.directory;

  static bool _ownedFolder(String name) =>
      name.startsWith('paper-') || name.startsWith('saved-paper-');

  Future<List<LocalPaper>> list() async {
    final root = await _root();
    if (!await root.exists()) return [];
    if (!await _regularDirectory(root)) {
      throw const FileSystemException('Invalid download directory');
    }
    final result = <LocalPaper>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory ||
          !_ownedFolder(
            entity.uri.pathSegments.where((s) => s.isNotEmpty).last,
          ) ||
          !await _regularDirectory(entity)) {
        continue;
      }
      await for (final child in entity.list(followLinks: false)) {
        final saved = entity.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last
            .startsWith('saved-paper-');
        if (child is! File || (!saved && child.path.endsWith('.part'))) {
          continue;
        }
        if (await FileSystemEntity.type(child.path, followLinks: false) !=
            FileSystemEntityType.file) {
          continue;
        }
        final name = child.uri.pathSegments.last;
        try {
          PaperDownloadService.validateFileName(name);
        } on FormatException {
          continue;
        }
        final stat = await child.stat();
        if (stat.size > 0) {
          result.add(LocalPaper(child, name, stat.size, stat.modified));
        }
      }
    }
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  /// Validate the exact owned file again before every open/share/delete action.
  Future<File> validate(LocalPaper paper) async {
    final root = await _root();
    final file = paper.file.absolute;
    final parent = file.parent;
    final folder = parent.uri.pathSegments.where((s) => s.isNotEmpty).last;
    PaperDownloadService.validateFileName(paper.name);
    if (!await _regularDirectory(root) ||
        parent.parent.absolute.path != root.absolute.path ||
        !_ownedFolder(folder) ||
        file.uri.pathSegments.last != paper.name ||
        (!folder.startsWith('saved-paper-') && file.path.endsWith('.part')) ||
        !await _regularDirectory(parent) ||
        await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
      throw const FileSystemException('Download no longer available');
    }
    return file;
  }

  Future<void> delete(LocalPaper paper) async {
    final file = await validate(paper);
    await file.delete();
    // Only remove an empty operation folder; never recursively delete content.
    try {
      if (await file.parent.list(followLinks: false).isEmpty) {
        await file.parent.delete();
      }
    } on FileSystemException {
      // The completed file is already deleted; a concurrent download may remain.
    }
  }
}
