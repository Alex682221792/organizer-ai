import 'package:equatable/equatable.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/runner_config.dart';

class ProjectsState extends Equatable {
  final List<ProjectModel> projects;
  final ProjectModel? selectedProject;
  final bool isLoading;
  final String? error;
  final String? pickedFolderPath;
  final RunnerConfig runnerConfig;
  final bool runnerInstalled;

  const ProjectsState({
    this.projects = const [],
    this.selectedProject,
    this.isLoading = false,
    this.error,
    this.pickedFolderPath,
    this.runnerConfig = const RunnerConfig(),
    this.runnerInstalled = false,
  });

  ProjectsState copyWith({
    List<ProjectModel>? projects,
    ProjectModel? selectedProject,
    bool clearSelectedProject = false,
    bool isLoading = false,
    String? error,
    bool clearError = false,
    String? pickedFolderPath,
    bool clearPickedFolder = false,
    RunnerConfig? runnerConfig,
    bool? runnerInstalled,
  }) {
    return ProjectsState(
      projects: projects ?? this.projects,
      selectedProject:
          clearSelectedProject ? null : (selectedProject ?? this.selectedProject),
      isLoading: isLoading,
      error: clearError ? null : (error ?? this.error),
      pickedFolderPath:
          clearPickedFolder ? null : (pickedFolderPath ?? this.pickedFolderPath),
      runnerConfig: runnerConfig ?? this.runnerConfig,
      runnerInstalled: runnerInstalled ?? this.runnerInstalled,
    );
  }

  @override
  List<Object?> get props =>
      [projects, selectedProject, isLoading, error, pickedFolderPath, runnerConfig, runnerInstalled];
}
