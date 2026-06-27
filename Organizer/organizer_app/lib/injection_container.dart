import 'package:get_it/get_it.dart';
import 'data/repositories/agent_repository.dart';
import 'data/repositories/folder_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/runner_config_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/services/refinement_service.dart';
import 'data/services/task_runner_service.dart';
import 'data/services/task_scan_service.dart';
import 'presentation/blocs/agents/agents_bloc.dart';
import 'presentation/blocs/folders/folders_bloc.dart';
import 'presentation/blocs/projects/projects_bloc.dart';
import 'presentation/blocs/tasks/tasks_bloc.dart';

final getIt = GetIt.instance;

void setupInjection() {
  getIt.registerLazySingleton<ProjectRepository>(() => ProjectRepository());
  getIt.registerLazySingleton<TaskRepository>(() => TaskRepository());
  getIt.registerLazySingleton<AgentRepository>(() => AgentRepository());
  getIt.registerLazySingleton<FolderRepository>(() => FolderRepository());
  getIt.registerLazySingleton<RunnerConfigRepository>(
      () => RunnerConfigRepository());
  getIt.registerLazySingleton<RefinementService>(() => RefinementService());
  getIt.registerLazySingleton<TaskScanService>(() => TaskScanService());
  getIt.registerLazySingleton<TaskRunnerService>(
      () => TaskRunnerService(getIt<RunnerConfigRepository>()));

  getIt.registerFactory<ProjectsBloc>(
    () => ProjectsBloc(
      getIt<ProjectRepository>(),
      getIt<RunnerConfigRepository>(),
    ),
  );
  getIt.registerFactory<TasksBloc>(
    () => TasksBloc(
      getIt<TaskRepository>(),
      getIt<TaskScanService>(),
      getIt<TaskRunnerService>(),
    ),
  );
  getIt.registerFactory<AgentsBloc>(
    () => AgentsBloc(getIt<AgentRepository>(), getIt<RefinementService>()),
  );
  getIt.registerFactory<FoldersBloc>(
    () => FoldersBloc(getIt<FolderRepository>()),
  );
}
