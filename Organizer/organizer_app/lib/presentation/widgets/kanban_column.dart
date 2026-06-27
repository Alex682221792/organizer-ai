import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/task_status.dart';
import '../blocs/folders/folders_bloc.dart';
import '../blocs/folders/folders_state.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../blocs/tasks/tasks_state.dart';
import '../dialogs/create_task_dialog.dart';
import 'task_card.dart';

enum _SortOrder { titleAsc, titleDesc, createdDesc, createdAsc, updatedDesc }

extension _SortOrderLabel on _SortOrder {
  String get label => switch (this) {
        _SortOrder.titleAsc => 'Título A–Z',
        _SortOrder.titleDesc => 'Título Z–A',
        _SortOrder.createdDesc => 'Más nuevas',
        _SortOrder.createdAsc => 'Más antiguas',
        _SortOrder.updatedDesc => 'Última actualización',
      };
}

class KanbanColumn extends StatefulWidget {
  final TaskStatus status;
  final ProjectModel project;

  const KanbanColumn({
    super.key,
    required this.status,
    required this.project,
  });

  @override
  State<KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<KanbanColumn> {
  _SortOrder _sortOrder = _SortOrder.createdDesc;

  Color _columnColor(TaskStatus s) => switch (s) {
        TaskStatus.backlog => Colors.grey,
        TaskStatus.pending => Colors.amber,
        TaskStatus.inProgress => Colors.blue,
        TaskStatus.review => Colors.purple,
        TaskStatus.blocked => Colors.red,
        TaskStatus.completed => Colors.green,
        TaskStatus.cancelled => Colors.grey,
      };

  List<TaskModel> _sorted(List<TaskModel> tasks) {
    final list = [...tasks];
    switch (_sortOrder) {
      case _SortOrder.titleAsc:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _SortOrder.titleDesc:
        list.sort((a, b) =>
            b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      case _SortOrder.createdDesc:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortOrder.createdAsc:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortOrder.updatedDesc:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _columnColor(widget.status);

    return BlocBuilder<TasksBloc, TasksState>(
      builder: (context, tasksState) {
        return BlocBuilder<FoldersBloc, FoldersState>(
          builder: (context, foldersState) {
            final selectedFolderId = foldersState.selectedFolderId;
            final allTasks =
                tasksState.tasksByStatus[widget.status] ?? <TaskModel>[];
            final filtered = selectedFolderId == null
                ? allTasks
                : allTasks
                    .where((t) => t.folderId == selectedFolderId)
                    .toList();
            final tasks = _sorted(filtered);

            return Container(
              width: 220,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Column header
                  Container(
                    padding: const EdgeInsets.only(
                        left: 10, right: 4, top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.status.displayName,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        PopupMenuButton<_SortOrder>(
                          tooltip: 'Ordenar',
                          icon: Icon(
                            Icons.sort,
                            size: 14,
                            color: theme.colorScheme.secondary
                                .withValues(alpha: 0.6),
                          ),
                          padding: EdgeInsets.zero,
                          initialValue: _sortOrder,
                          onSelected: (order) =>
                              setState(() => _sortOrder = order),
                          itemBuilder: (_) => _SortOrder.values
                              .map((o) => PopupMenuItem(
                                    value: o,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _sortOrder == o
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(o.label,
                                            style:
                                                theme.textTheme.bodySmall),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${tasks.length}',
                            style: TextStyle(
                              fontSize: 11,
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Task list
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.03),
                        border: Border(
                          left: BorderSide(
                              color: accent.withValues(alpha: 0.2)),
                          right: BorderSide(
                              color: accent.withValues(alpha: 0.2)),
                          bottom: BorderSide(
                              color: accent.withValues(alpha: 0.2)),
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) => TaskCard(
                          task: tasks[i],
                          project: widget.project,
                        ),
                      ),
                    ),
                  ),
                  // Add button for backlog
                  if (widget.status == TaskStatus.backlog)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => MultiBlocProvider(
                                providers: [
                                  BlocProvider.value(
                                      value: context.read<TasksBloc>()),
                                  BlocProvider.value(
                                      value: context.read<FoldersBloc>()),
                                ],
                                child:
                                    CreateTaskDialog(project: widget.project),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Nueva tarea'),
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
