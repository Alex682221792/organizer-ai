import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import '../../data/models/project_model.dart';
import '../../data/models/scanned_task.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../blocs/tasks/tasks_event.dart';

enum _SortOrder { titleAsc, titleDesc, pathAsc }

class ScanResultsDialog extends StatefulWidget {
  final List<ScannedTask> scannedTasks;
  final ProjectModel project;

  const ScanResultsDialog({
    super.key,
    required this.scannedTasks,
    required this.project,
  });

  @override
  State<ScanResultsDialog> createState() => _ScanResultsDialogState();
}

class _ScanResultsDialogState extends State<ScanResultsDialog> {
  late final Set<ScannedTask> _selected;
  _SortOrder _sortOrder = _SortOrder.titleAsc;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.scannedTasks);
  }

  List<ScannedTask> get _sorted {
    final list = [...widget.scannedTasks];
    switch (_sortOrder) {
      case _SortOrder.titleAsc:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _SortOrder.titleDesc:
        list.sort((a, b) =>
            b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      case _SortOrder.pathAsc:
        list.sort((a, b) => a.sourcePath.compareTo(b.sourcePath));
    }
    return list;
  }

  void _toggleAll(bool select) {
    setState(() {
      if (select) {
        _selected.addAll(widget.scannedTasks);
      } else {
        _selected.clear();
      }
    });
  }

  void _import() {
    context.read<TasksBloc>().add(
          ImportScannedTasks(
              project: widget.project, tasks: _selected.toList()),
        );
    Navigator.of(context).pop();
  }

  String _sortLabel(_SortOrder order) => switch (order) {
        _SortOrder.titleAsc => 'Título A–Z',
        _SortOrder.titleDesc => 'Título Z–A',
        _SortOrder.pathAsc => 'Ruta',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = _sorted;
    final allSelected = _selected.length == widget.scannedTasks.length;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.document_scanner_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tasks.isEmpty
                          ? 'No se encontraron tareas'
                          : 'Tareas detectadas (${tasks.length})',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (tasks.isNotEmpty)
                    PopupMenuButton<_SortOrder>(
                      tooltip: 'Ordenar',
                      icon: const Icon(Icons.sort, size: 18),
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
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_sortLabel(o)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      context
                          .read<TasksBloc>()
                          .add(const ClearScannedTasks());
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            if (tasks.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 40,
                            color: theme.colorScheme.secondary
                                .withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron archivos con definiciones de tareas.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Los agentes pueden crear tareas en archivos .md o .txt\nusando # Task:, YAML frontmatter con title:, o TASK: (en .txt).',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary
                                  .withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // Select all toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Checkbox(
                      value: allSelected,
                      tristate: true,
                      onChanged: (_) => _toggleAll(!allSelected),
                    ),
                    Text('Seleccionar todos',
                        style: theme.textTheme.bodySmall),
                    const Spacer(),
                    Text(
                      '${_selected.length} seleccionada${_selected.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.secondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Task list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    final isSelected = _selected.contains(task);
                    final relPath = _relativePath(task.sourcePath);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (_) => setState(() {
                        if (isSelected) {
                          _selected.remove(task);
                        } else {
                          _selected.add(task);
                        }
                      }),
                      title: Text(
                        task.title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (task.instructions.isNotEmpty)
                            Text(
                              task.instructions,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.insert_drive_file_outlined,
                                  size: 11,
                                  color: theme.colorScheme.secondary
                                      .withValues(alpha: 0.6)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  relPath,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.secondary
                                        .withValues(alpha: 0.6),
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
            ],

            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      context
                          .read<TasksBloc>()
                          .add(const ClearScannedTasks());
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancelar'),
                  ),
                  if (tasks.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _selected.isEmpty ? null : _import,
                      icon: const Icon(Icons.add_task, size: 16),
                      label: Text(
                        _selected.isEmpty
                            ? 'Importar'
                            : 'Importar ${_selected.length}',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativePath(String absPath) {
    try {
      return p.relative(absPath, from: widget.project.folderPath);
    } catch (_) {
      return p.basename(absPath);
    }
  }
}
