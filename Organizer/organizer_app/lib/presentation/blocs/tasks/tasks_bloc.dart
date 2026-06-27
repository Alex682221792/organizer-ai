import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/task_status.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/services/task_runner_service.dart';
import '../../../data/services/task_scan_service.dart';
import 'tasks_event.dart';
import 'tasks_state.dart';

class _PollTasks extends TasksEvent {
  final ProjectModel project;
  const _PollTasks(this.project);
  @override
  List<Object?> get props => [project];
}

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final TaskRepository _taskRepository;
  final TaskScanService _taskScanService;
  final TaskRunnerService _taskRunnerService;
  Timer? _pollTimer;

  TasksBloc(this._taskRepository, this._taskScanService, this._taskRunnerService)
      : super(const TasksState()) {
    on<LoadTasks>(_onLoadTasks);
    on<_PollTasks>(_onPollTasks);
    on<CreateTask>(_onCreateTask);
    on<UpdateTaskStatus>(_onUpdateTaskStatus);
    on<UpdateTaskAgents>(_onUpdateTaskAgents);
    on<UpdateTaskDependencies>(_onUpdateTaskDependencies);
    on<UpdateTaskFolder>(_onUpdateTaskFolder);
    on<DeleteTask>(_onDeleteTask);
    on<SelectTask>(_onSelectTask);
    on<ClearSelectedTask>(_onClearSelectedTask);
    on<ScanTasks>(_onScanTasks);
    on<ImportScannedTasks>(_onImportScannedTasks);
    on<ClearScannedTasks>(_onClearScannedTasks);
    on<RunTaskNow>(_onRunTaskNow);
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }

  void _startPolling(ProjectModel project) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isClosed) add(_PollTasks(project));
    });
  }

  Map<TaskStatus, List<TaskModel>> _buildStatusMap(List<TaskModel> tasks) {
    final map = <TaskStatus, List<TaskModel>>{};
    for (final s in TaskStatus.values) {
      map[s] = [];
    }
    for (final task in tasks) {
      map[task.status]!.add(task);
    }
    return map;
  }

  Future<void> _onLoadTasks(
      LoadTasks event, Emitter<TasksState> emit) async {
    _startPolling(event.project);
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final tasks = await _taskRepository.loadTasks(event.project);
      emit(state.copyWith(tasksByStatus: _buildStatusMap(tasks)));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onPollTasks(
      _PollTasks event, Emitter<TasksState> emit) async {
    try {
      final tasks = await _taskRepository.loadTasks(event.project);
      TaskModel? updatedSelected = state.selectedTask;
      if (updatedSelected != null) {
        final fresh = tasks.where((t) => t.id == updatedSelected!.id);
        if (fresh.isNotEmpty) updatedSelected = fresh.first;
      }
      emit(state.copyWith(
        tasksByStatus: _buildStatusMap(tasks),
        selectedTask: updatedSelected,
      ));
    } catch (_) {}
  }

  Future<void> _onCreateTask(
      CreateTask event, Emitter<TasksState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final refined = event.refinementResult;

      await _taskRepository.createTask(
        project: event.project,
        title: event.title,
        instructions: event.instructions,
        agentIds: refined?.agentIds ?? [],
        agentSystemPrompts: refined?.agentSystemPrompts ?? {},
        refinedTaskMd: refined?.taskMd,
        folderId: event.folderId,
      );

      final tasks = await _taskRepository.loadTasks(event.project);
      emit(state.copyWith(tasksByStatus: _buildStatusMap(tasks)));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdateTaskStatus(
      UpdateTaskStatus event, Emitter<TasksState> emit) async {
    try {
      await _taskRepository.updateTaskStatus(
          event.task, event.project, event.newStatus);
      final tasks = await _taskRepository.loadTasks(event.project);

      final updatedSelected = state.selectedTask?.id == event.task.id
          ? tasks.firstWhere((t) => t.id == event.task.id,
              orElse: () => state.selectedTask!)
          : state.selectedTask;

      emit(state.copyWith(
        tasksByStatus: _buildStatusMap(tasks),
        selectedTask: updatedSelected,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteTask(
      DeleteTask event, Emitter<TasksState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _taskRepository.deleteTask(event.task, event.project);
      final tasks = await _taskRepository.loadTasks(event.project);
      final wasSelected = state.selectedTask?.id == event.task.id;
      emit(state.copyWith(
        tasksByStatus: _buildStatusMap(tasks),
        clearSelectedTask: wasSelected,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdateTaskAgents(
      UpdateTaskAgents event, Emitter<TasksState> emit) async {
    try {
      final updatedTask = await _taskRepository.updateTaskAgents(
          event.task, event.project, event.agentIds);
      final tasks = await _taskRepository.loadTasks(event.project);
      emit(state.copyWith(
        tasksByStatus: _buildStatusMap(tasks),
        selectedTask: updatedTask,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdateTaskDependencies(
      UpdateTaskDependencies event, Emitter<TasksState> emit) async {
    try {
      final updatedTask = await _taskRepository.updateTaskDependencies(
          event.task, event.project, event.blockedBy);
      final tasks = await _taskRepository.loadTasks(event.project);
      emit(state.copyWith(
        tasksByStatus: _buildStatusMap(tasks),
        selectedTask: updatedTask,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdateTaskFolder(
      UpdateTaskFolder event, Emitter<TasksState> emit) async {
    try {
      final updatedTask = await _taskRepository.updateTaskFolder(
          event.task, event.project, event.folderId);
      final tasks = await _taskRepository.loadTasks(event.project);
      emit(state.copyWith(
        tasksByStatus: _buildStatusMap(tasks),
        selectedTask: state.selectedTask?.id == event.task.id
            ? updatedTask
            : state.selectedTask,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onSelectTask(SelectTask event, Emitter<TasksState> emit) {
    emit(state.copyWith(selectedTask: event.task));
  }

  void _onClearSelectedTask(
      ClearSelectedTask event, Emitter<TasksState> emit) {
    emit(state.copyWith(clearSelectedTask: true));
  }

  Future<void> _onScanTasks(
      ScanTasks event, Emitter<TasksState> emit) async {
    emit(state.copyWith(isScanning: true, clearError: true));
    try {
      final found = await _taskScanService.scan(event.project);
      emit(state.copyWith(scannedTasks: found, isScanning: false));
    } catch (e) {
      emit(state.copyWith(
          error: 'Error al escanear: $e', isScanning: false));
    }
  }

  Future<void> _onImportScannedTasks(
      ImportScannedTasks event, Emitter<TasksState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      for (final scanned in event.tasks) {
        await _taskRepository.createTask(
          project: event.project,
          title: scanned.title,
          instructions: scanned.instructions,
        );
      }
      final tasks = await _taskRepository.loadTasks(event.project);
      emit(state.copyWith(
        tasksByStatus: _buildStatusMap(tasks),
        clearScannedTasks: true,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onClearScannedTasks(
      ClearScannedTasks event, Emitter<TasksState> emit) {
    emit(state.copyWith(clearScannedTasks: true));
  }

  Future<void> _onRunTaskNow(
      RunTaskNow event, Emitter<TasksState> emit) async {
    emit(state.copyWith(
      runningTaskIds: {...state.runningTaskIds, event.task.id},
      clearError: true,
    ));
    try {
      await _taskRunnerService.runTask(event.task, event.project);
      final tasks = await _taskRepository.loadTasks(event.project);
      final updatedSelected = state.selectedTask?.id == event.task.id
          ? tasks.firstWhere((t) => t.id == event.task.id,
              orElse: () => state.selectedTask!)
          : state.selectedTask;
      emit(state.copyWith(
        tasksByStatus: _buildStatusMap(tasks),
        selectedTask: updatedSelected,
        runningTaskIds: state.runningTaskIds.difference({event.task.id}),
      ));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
        runningTaskIds: state.runningTaskIds.difference({event.task.id}),
      ));
    }
  }
}
