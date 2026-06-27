import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/folder_repository.dart';
import 'folders_event.dart';
import 'folders_state.dart';

class FoldersBloc extends Bloc<FoldersEvent, FoldersState> {
  final FolderRepository _folderRepository;

  FoldersBloc(this._folderRepository) : super(const FoldersState()) {
    on<LoadFolders>(_onLoad);
    on<CreateFolder>(_onCreate);
    on<UpdateFolder>(_onUpdate);
    on<DeleteFolder>(_onDelete);
    on<SelectFolder>(_onSelect);
  }

  Future<void> _onLoad(LoadFolders event, Emitter<FoldersState> emit) async {
    emit(state.copyWith(isLoading: true, clearSelectedFolder: true));
    final folders = await _folderRepository.loadFolders(event.project);
    emit(state.copyWith(folders: folders));
  }

  Future<void> _onCreate(
      CreateFolder event, Emitter<FoldersState> emit) async {
    await _folderRepository.createFolder(event.project, event.name);
    final folders = await _folderRepository.loadFolders(event.project);
    emit(state.copyWith(folders: folders));
  }

  Future<void> _onUpdate(
      UpdateFolder event, Emitter<FoldersState> emit) async {
    await _folderRepository.updateFolder(event.project, event.folder);
    final folders = await _folderRepository.loadFolders(event.project);
    emit(state.copyWith(folders: folders));
  }

  Future<void> _onDelete(
      DeleteFolder event, Emitter<FoldersState> emit) async {
    await _folderRepository.deleteFolder(event.project, event.folderId);
    final folders = await _folderRepository.loadFolders(event.project);
    final clearSel = state.selectedFolderId == event.folderId;
    emit(state.copyWith(
      folders: folders,
      clearSelectedFolder: clearSel,
    ));
  }

  void _onSelect(SelectFolder event, Emitter<FoldersState> emit) {
    if (event.folderId == null) {
      emit(state.copyWith(clearSelectedFolder: true));
    } else {
      emit(state.copyWith(selectedFolderId: event.folderId));
    }
  }
}
