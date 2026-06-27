import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/runner_config_repository.dart';
import 'projects_event.dart';
import 'projects_state.dart';

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  final ProjectRepository _projectRepository;
  final RunnerConfigRepository _runnerConfigRepository;

  ProjectsBloc(this._projectRepository, this._runnerConfigRepository)
      : super(const ProjectsState()) {
    on<LoadProjects>(_onLoadProjects);
    on<CreateProject>(_onCreateProject);
    on<DeleteProject>(_onDeleteProject);
    on<SelectProject>(_onSelectProject);
    on<PickProjectFolder>(_onPickProjectFolder);
    on<ImportProject>(_onImportProject);
    on<ToggleProjectScheduler>(_onToggleProjectScheduler);
    on<LoadRunnerConfig>(_onLoadRunnerConfig);
    on<SaveRunnerConfig>(_onSaveRunnerConfig);
    on<InstallRunner>(_onInstallRunner);
    on<UninstallRunner>(_onUninstallRunner);
  }

  Future<void> _onLoadProjects(
      LoadProjects event, Emitter<ProjectsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final projects = await _projectRepository.loadProjects();
      emit(state.copyWith(projects: projects));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onCreateProject(
      CreateProject event, Emitter<ProjectsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _projectRepository.createProject(
        name: event.name,
        description: event.description,
        folderPath: event.folderPath,
        color: event.color,
      );
      final projects = await _projectRepository.loadProjects();
      emit(state.copyWith(projects: projects, clearPickedFolder: true));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteProject(
      DeleteProject event, Emitter<ProjectsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _projectRepository.deleteProject(event.project);
      final projects = await _projectRepository.loadProjects();
      final stillSelected = projects.any((p) => p.id == state.selectedProject?.id);
      emit(state.copyWith(
        projects: projects,
        clearSelectedProject: !stillSelected,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onSelectProject(SelectProject event, Emitter<ProjectsState> emit) {
    emit(state.copyWith(selectedProject: event.project));
  }

  Future<void> _onPickProjectFolder(
      PickProjectFolder event, Emitter<ProjectsState> emit) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        emit(state.copyWith(pickedFolderPath: result));
      }
    } catch (e) {
      emit(state.copyWith(error: 'Could not pick folder: $e'));
    }
  }

  Future<void> _onImportProject(
      ImportProject event, Emitter<ProjectsState> emit) async {
    try {
      final folderPath = await FilePicker.platform.getDirectoryPath();
      if (folderPath == null) return;
      emit(state.copyWith(isLoading: true, clearError: true));
      await _projectRepository.importProject(folderPath);
      final projects = await _projectRepository.loadProjects();
      emit(state.copyWith(projects: projects));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onToggleProjectScheduler(
      ToggleProjectScheduler event, Emitter<ProjectsState> emit) async {
    try {
      final updated = event.project.copyWith(
        schedulerEnabled: !event.project.schedulerEnabled,
      );
      await _projectRepository.updateProject(updated);
      final projects = await _projectRepository.loadProjects();
      final selectedProject = state.selectedProject?.id == updated.id
          ? updated
          : state.selectedProject;
      emit(state.copyWith(projects: projects, selectedProject: selectedProject));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLoadRunnerConfig(
      LoadRunnerConfig event, Emitter<ProjectsState> emit) async {
    final config = await _runnerConfigRepository.load();
    final installed = await _runnerConfigRepository.isLaunchAgentInstalled();
    emit(state.copyWith(runnerConfig: config, runnerInstalled: installed));
  }

  Future<void> _onSaveRunnerConfig(
      SaveRunnerConfig event, Emitter<ProjectsState> emit) async {
    try {
      await _runnerConfigRepository.save(event.config);
      emit(state.copyWith(runnerConfig: event.config));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onInstallRunner(
      InstallRunner event, Emitter<ProjectsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _runnerConfigRepository.installRunner(event.config);
      emit(state.copyWith(runnerConfig: event.config, runnerInstalled: true));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUninstallRunner(
      UninstallRunner event, Emitter<ProjectsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _runnerConfigRepository.uninstallRunner();
      emit(state.copyWith(runnerInstalled: false));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
