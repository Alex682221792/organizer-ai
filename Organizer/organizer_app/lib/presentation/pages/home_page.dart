import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../blocs/projects/projects_bloc.dart';
import '../blocs/projects/projects_state.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../blocs/tasks/tasks_event.dart';
import '../blocs/tasks/tasks_state.dart';
import '../dialogs/scan_results_dialog.dart';
import '../panels/shared_chat_panel.dart';
import '../panels/task_detail_panel.dart';
import '../widgets/kanban_board.dart';
import '../widgets/project_sidebar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _panelCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<TasksBloc, TasksState>(
      listenWhen: (prev, curr) =>
          curr.scannedTasks.isNotEmpty &&
          prev.scannedTasks != curr.scannedTasks,
      listener: (context, state) {
        final project = context.read<ProjectsBloc>().state.selectedProject;
        if (project == null) return;
        showDialog(
          context: context,
          builder: (_) => BlocProvider.value(
            value: context.read<TasksBloc>(),
            child: ScanResultsDialog(
              scannedTasks: state.scannedTasks,
              project: project,
            ),
          ),
        ).then((_) {
          if (!context.mounted) return;
          final current = context.read<TasksBloc>().state;
          if (current.scannedTasks.isNotEmpty) {
            context.read<TasksBloc>().add(const ClearScannedTasks());
          }
        });
      },
      child: Scaffold(
        body: Column(
          children: [
            // Custom top bar
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  BlocBuilder<ProjectsBloc, ProjectsState>(
                    builder: (context, state) {
                      if (state.selectedProject == null) return const SizedBox();
                      return Text(
                        state.selectedProject!.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _panelCollapsed
                          ? Icons.chevron_left
                          : Icons.chevron_right,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _panelCollapsed = !_panelCollapsed),
                    tooltip: _panelCollapsed ? 'Abrir panel' : 'Cerrar panel',
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: Row(
                children: [
                  const ProjectSidebar(),
                  VerticalDivider(
                    width: 1,
                    color: theme.dividerColor,
                  ),
                  const Expanded(child: KanbanBoard()),
                  BlocBuilder<ProjectsBloc, ProjectsState>(
                    builder: (context, projState) {
                      final project = projState.selectedProject;
                      if (project == null) return const SizedBox();
                      return BlocBuilder<TasksBloc, TasksState>(
                        builder: (context, tasksState) {
                          final panel = tasksState.selectedTask != null
                              ? TaskDetailPanel(
                                  task: tasksState.selectedTask!,
                                  project: project,
                                )
                              : SharedChatPanel(project: project);

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            width: _panelCollapsed ? 0 : 360,
                            clipBehavior: Clip.hardEdge,
                            decoration: const BoxDecoration(),
                            child: panel,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
