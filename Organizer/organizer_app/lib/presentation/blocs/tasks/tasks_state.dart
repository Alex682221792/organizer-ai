import 'package:equatable/equatable.dart';
import '../../../data/models/scanned_task.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/task_status.dart';

class TasksState extends Equatable {
  final Map<TaskStatus, List<TaskModel>> tasksByStatus;
  final TaskModel? selectedTask;
  final bool isLoading;
  final String? error;
  final List<ScannedTask> scannedTasks;
  final bool isScanning;
  final Set<String> runningTaskIds;

  const TasksState({
    this.tasksByStatus = const {},
    this.selectedTask,
    this.isLoading = false,
    this.error,
    this.scannedTasks = const [],
    this.isScanning = false,
    this.runningTaskIds = const {},
  });

  bool isTaskRunning(String taskId) => runningTaskIds.contains(taskId);

  TasksState copyWith({
    Map<TaskStatus, List<TaskModel>>? tasksByStatus,
    TaskModel? selectedTask,
    bool clearSelectedTask = false,
    bool isLoading = false,
    String? error,
    bool clearError = false,
    List<ScannedTask>? scannedTasks,
    bool clearScannedTasks = false,
    bool isScanning = false,
    Set<String>? runningTaskIds,
  }) {
    return TasksState(
      tasksByStatus: tasksByStatus ?? this.tasksByStatus,
      selectedTask:
          clearSelectedTask ? null : (selectedTask ?? this.selectedTask),
      isLoading: isLoading,
      error: clearError ? null : (error ?? this.error),
      scannedTasks:
          clearScannedTasks ? [] : (scannedTasks ?? this.scannedTasks),
      isScanning: isScanning,
      runningTaskIds: runningTaskIds ?? this.runningTaskIds,
    );
  }

  @override
  List<Object?> get props => [
        tasksByStatus,
        selectedTask,
        isLoading,
        error,
        scannedTasks,
        isScanning,
        runningTaskIds,
      ];
}
