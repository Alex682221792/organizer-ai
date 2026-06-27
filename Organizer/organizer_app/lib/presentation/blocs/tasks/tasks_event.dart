import 'package:equatable/equatable.dart';
import '../../../data/models/agent_model.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/scanned_task.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/task_status.dart';
import '../../../data/services/refinement_service.dart';

abstract class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasks extends TasksEvent {
  final ProjectModel project;

  const LoadTasks(this.project);

  @override
  List<Object?> get props => [project];
}

class CreateTask extends TasksEvent {
  final ProjectModel project;
  final String title;
  final String instructions;
  final List<AgentModel> agents;
  final String? folderId;
  final RefinementResult? refinementResult;

  const CreateTask({
    required this.project,
    required this.title,
    required this.instructions,
    this.agents = const [],
    this.folderId,
    this.refinementResult,
  });

  @override
  List<Object?> get props => [project, title, instructions, agents, folderId, refinementResult];
}

class UpdateTaskFolder extends TasksEvent {
  final TaskModel task;
  final ProjectModel project;
  final String? folderId;

  const UpdateTaskFolder({
    required this.task,
    required this.project,
    this.folderId,
  });

  @override
  List<Object?> get props => [task, project, folderId];
}

class UpdateTaskStatus extends TasksEvent {
  final TaskModel task;
  final ProjectModel project;
  final TaskStatus newStatus;

  const UpdateTaskStatus({
    required this.task,
    required this.project,
    required this.newStatus,
  });

  @override
  List<Object?> get props => [task, project, newStatus];
}

class DeleteTask extends TasksEvent {
  final TaskModel task;
  final ProjectModel project;

  const DeleteTask({required this.task, required this.project});

  @override
  List<Object?> get props => [task, project];
}

class SelectTask extends TasksEvent {
  final TaskModel task;

  const SelectTask(this.task);

  @override
  List<Object?> get props => [task];
}

class ClearSelectedTask extends TasksEvent {
  const ClearSelectedTask();
}

class ScanTasks extends TasksEvent {
  final ProjectModel project;

  const ScanTasks(this.project);

  @override
  List<Object?> get props => [project];
}

class ImportScannedTasks extends TasksEvent {
  final ProjectModel project;
  final List<ScannedTask> tasks;

  const ImportScannedTasks({required this.project, required this.tasks});

  @override
  List<Object?> get props => [project, tasks];
}

class ClearScannedTasks extends TasksEvent {
  const ClearScannedTasks();
}

class UpdateTaskAgents extends TasksEvent {
  final TaskModel task;
  final ProjectModel project;
  final List<String> agentIds;

  const UpdateTaskAgents({
    required this.task,
    required this.project,
    required this.agentIds,
  });

  @override
  List<Object?> get props => [task, project, agentIds];
}

class UpdateTaskDependencies extends TasksEvent {
  final TaskModel task;
  final ProjectModel project;
  final List<String> blockedBy;

  const UpdateTaskDependencies({
    required this.task,
    required this.project,
    required this.blockedBy,
  });

  @override
  List<Object?> get props => [task, project, blockedBy];
}

class RunTaskNow extends TasksEvent {
  final TaskModel task;
  final ProjectModel project;

  const RunTaskNow({required this.task, required this.project});

  @override
  List<Object?> get props => [task, project];
}
