import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/task_status.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../blocs/tasks/tasks_event.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final ProjectModel project;

  const TaskCard({super.key, required this.task, required this.project});

  Color _statusColor(TaskStatus s) => switch (s) {
        TaskStatus.backlog => Colors.grey,
        TaskStatus.pending => Colors.amber,
        TaskStatus.inProgress => Colors.blue,
        TaskStatus.review => Colors.purple,
        TaskStatus.blocked => Colors.red,
        TaskStatus.completed => Colors.green,
        TaskStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('dd/MM/yy');

    return GestureDetector(
      onTap: () => context.read<TasksBloc>().add(SelectTask(task)),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _ContextMenu(task: task, project: project),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(task.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.status.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        color: _statusColor(task.status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (task.blockedBy.isNotEmpty)
                    Tooltip(
                      message: 'Bloqueada por ${task.blockedBy.length} tarea(s)',
                      child: const Icon(Icons.link, size: 14, color: Colors.red),
                    ),
                  if (task.needsInput)
                    const Icon(Icons.notification_important_outlined,
                        size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    fmt.format(task.updatedAt),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextMenu extends StatelessWidget {
  final TaskModel task;
  final ProjectModel project;

  const _ContextMenu({required this.task, required this.project});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      iconSize: 16,
      padding: EdgeInsets.zero,
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'divider_label', enabled: false,
            child: Text('Mover a...', style: TextStyle(fontSize: 11))),
        ...TaskStatus.values
            .where((s) => s != task.status)
            .map((s) => PopupMenuItem(
                  value: 'status_${s.jsonValue}',
                  child: Text(s.displayName, style: const TextStyle(fontSize: 13)),
                )),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Eliminar', style: TextStyle(color: Colors.red, fontSize: 13)),
        ),
      ],
      onSelected: (value) {
        if (value == 'delete') {
          context.read<TasksBloc>().add(DeleteTask(task: task, project: project));
        } else if (value.startsWith('status_')) {
          final statusStr = value.substring('status_'.length);
          final newStatus = TaskStatus.fromJson(statusStr);
          context.read<TasksBloc>().add(
                UpdateTaskStatus(task: task, project: project, newStatus: newStatus),
              );
        }
      },
    );
  }
}
