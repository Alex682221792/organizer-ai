import 'package:equatable/equatable.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/runner_config.dart';

abstract class ProjectsEvent extends Equatable {
  const ProjectsEvent();

  @override
  List<Object?> get props => [];
}

class LoadProjects extends ProjectsEvent {
  const LoadProjects();
}

class CreateProject extends ProjectsEvent {
  final String name;
  final String description;
  final String folderPath;
  final String color;

  const CreateProject({
    required this.name,
    required this.description,
    required this.folderPath,
    required this.color,
  });

  @override
  List<Object?> get props => [name, description, folderPath, color];
}

class DeleteProject extends ProjectsEvent {
  final ProjectModel project;

  const DeleteProject(this.project);

  @override
  List<Object?> get props => [project];
}

class SelectProject extends ProjectsEvent {
  final ProjectModel project;

  const SelectProject(this.project);

  @override
  List<Object?> get props => [project];
}

class PickProjectFolder extends ProjectsEvent {
  const PickProjectFolder();
}

class ImportProject extends ProjectsEvent {
  const ImportProject();
}

class ToggleProjectScheduler extends ProjectsEvent {
  final ProjectModel project;
  const ToggleProjectScheduler(this.project);
  @override
  List<Object?> get props => [project];
}

class LoadRunnerConfig extends ProjectsEvent {
  const LoadRunnerConfig();
}

class SaveRunnerConfig extends ProjectsEvent {
  final RunnerConfig config;
  const SaveRunnerConfig(this.config);
  @override
  List<Object?> get props => [config];
}

class InstallRunner extends ProjectsEvent {
  final RunnerConfig config;
  const InstallRunner(this.config);
  @override
  List<Object?> get props => [config];
}

class UninstallRunner extends ProjectsEvent {
  const UninstallRunner();
}
