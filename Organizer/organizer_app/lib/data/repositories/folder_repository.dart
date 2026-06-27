import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../models/folder_model.dart';
import '../models/project_model.dart';

class FolderRepository {
  final _uuid = const Uuid();

  String _foldersPath(ProjectModel project) =>
      p.join(project.folderPath, AppConstants.foldersFile);

  Future<List<FolderModel>> loadFolders(ProjectModel project) async {
    try {
      final file = File(_foldersPath(project));
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => FolderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(ProjectModel project, List<FolderModel> folders) async {
    final file = File(_foldersPath(project));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert(folders.map((f) => f.toJson()).toList()),
    );
  }

  Future<FolderModel> createFolder(ProjectModel project, String name) async {
    final folders = await loadFolders(project);
    final folder = FolderModel(id: _uuid.v4(), name: name);
    await _save(project, [...folders, folder]);
    return folder;
  }

  Future<void> updateFolder(ProjectModel project, FolderModel updated) async {
    final folders = await loadFolders(project);
    final next = folders.map((f) => f.id == updated.id ? updated : f).toList();
    await _save(project, next);
  }

  Future<void> deleteFolder(ProjectModel project, String folderId) async {
    final folders = await loadFolders(project);
    await _save(project, folders.where((f) => f.id != folderId).toList());
  }
}
