import 'package:equatable/equatable.dart';
import '../../../data/models/folder_model.dart';

class FoldersState extends Equatable {
  final List<FolderModel> folders;
  final String? selectedFolderId; // null = all folders
  final bool isLoading;

  const FoldersState({
    this.folders = const [],
    this.selectedFolderId,
    this.isLoading = false,
  });

  FoldersState copyWith({
    List<FolderModel>? folders,
    String? selectedFolderId,
    bool clearSelectedFolder = false,
    bool isLoading = false,
  }) {
    return FoldersState(
      folders: folders ?? this.folders,
      selectedFolderId: clearSelectedFolder
          ? null
          : (selectedFolderId ?? this.selectedFolderId),
      isLoading: isLoading,
    );
  }

  FolderModel? get selectedFolder => selectedFolderId == null
      ? null
      : folders.where((f) => f.id == selectedFolderId).firstOrNull;

  @override
  List<Object?> get props => [folders, selectedFolderId, isLoading];
}
