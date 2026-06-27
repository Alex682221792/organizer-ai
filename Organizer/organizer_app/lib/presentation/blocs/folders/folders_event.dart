import 'package:equatable/equatable.dart';
import '../../../data/models/folder_model.dart';
import '../../../data/models/project_model.dart';

abstract class FoldersEvent extends Equatable {
  const FoldersEvent();

  @override
  List<Object?> get props => [];
}

class LoadFolders extends FoldersEvent {
  final ProjectModel project;
  const LoadFolders(this.project);

  @override
  List<Object?> get props => [project];
}

class CreateFolder extends FoldersEvent {
  final ProjectModel project;
  final String name;
  const CreateFolder({required this.project, required this.name});

  @override
  List<Object?> get props => [project, name];
}

class UpdateFolder extends FoldersEvent {
  final ProjectModel project;
  final FolderModel folder;
  const UpdateFolder({required this.project, required this.folder});

  @override
  List<Object?> get props => [project, folder];
}

class DeleteFolder extends FoldersEvent {
  final ProjectModel project;
  final String folderId;
  const DeleteFolder({required this.project, required this.folderId});

  @override
  List<Object?> get props => [project, folderId];
}

class SelectFolder extends FoldersEvent {
  final String? folderId;
  const SelectFolder(this.folderId);

  @override
  List<Object?> get props => [folderId];
}
