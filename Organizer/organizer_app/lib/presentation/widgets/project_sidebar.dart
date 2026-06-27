import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/project_model.dart';
import '../blocs/agents/agents_bloc.dart';
import '../blocs/agents/agents_event.dart';
import '../blocs/folders/folders_bloc.dart';
import '../blocs/folders/folders_event.dart';
import '../blocs/folders/folders_state.dart';
import '../blocs/projects/projects_bloc.dart';
import '../blocs/projects/projects_event.dart';
import '../blocs/projects/projects_state.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../blocs/tasks/tasks_event.dart';
import '../blocs/tasks/tasks_state.dart';
import '../dialogs/create_project_dialog.dart';
import '../dialogs/folder_attributes_dialog.dart';
import '../dialogs/manage_agents_dialog.dart';
import '../dialogs/scheduler_settings_dialog.dart';

Color _hexToColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

class ProjectSidebar extends StatelessWidget {
  const ProjectSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<ProjectsBloc, ProjectsState>(
      builder: (context, state) {
        return Container(
          width: 220,
          color: theme.scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Proyectos',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: state.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : state.projects.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Sin proyectos.\nCrea uno con el botón +',
                              style: theme.textTheme.bodySmall,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: state.projects.length,
                            itemBuilder: (context, i) {
                              final project = state.projects[i];
                              final isSelected =
                                  state.selectedProject?.id == project.id;
                              return _ProjectTile(
                                project: project,
                                isSelected: isSelected,
                                onTap: () {
                                  context
                                      .read<ProjectsBloc>()
                                      .add(SelectProject(project));
                                  context
                                      .read<TasksBloc>()
                                      .add(LoadTasks(project));
                                  context
                                      .read<AgentsBloc>()
                                      .add(LoadAgents(project));
                                  context
                                      .read<FoldersBloc>()
                                      .add(LoadFolders(project));
                                },
                                onDelete: () {
                                  context
                                      .read<ProjectsBloc>()
                                      .add(DeleteProject(project));
                                },
                                onManageAgents: () {
                                  context
                                      .read<AgentsBloc>()
                                      .add(LoadAgents(project));
                                  showDialog(
                                    context: context,
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<AgentsBloc>(),
                                      child: ManageAgentsDialog(
                                          project: project),
                                    ),
                                  );
                                },
                                onToggleScheduler: () {
                                  context
                                      .read<ProjectsBloc>()
                                      .add(ToggleProjectScheduler(project));
                                },
                              );
                            },
                          ),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.add, size: 18),
                title: const Text('Nuevo proyecto'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => BlocProvider.value(
                      value: context.read<ProjectsBloc>(),
                      child: const CreateProjectDialog(),
                    ),
                  );
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_open_outlined, size: 18),
                title: const Text('Abrir proyecto'),
                onTap: () =>
                    context.read<ProjectsBloc>().add(const ImportProject()),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.schedule_outlined, size: 18),
                title: const Text('Scheduler'),
                onTap: () {
                  context.read<ProjectsBloc>().add(const LoadRunnerConfig());
                  showDialog(
                    context: context,
                    builder: (_) => BlocProvider.value(
                      value: context.read<ProjectsBloc>(),
                      child: const SchedulerSettingsDialog(),
                    ),
                  );
                },
              ),
              BlocBuilder<ProjectsBloc, ProjectsState>(
                builder: (context, state) {
                  final project = state.selectedProject;
                  if (project == null) return const SizedBox();
                  return BlocBuilder<TasksBloc, TasksState>(
                    builder: (context, tasksState) {
                      final isScanning = tasksState.isScanning;
                      return ListTile(
                        dense: true,
                        leading: isScanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5),
                              )
                            : const Icon(
                                Icons.document_scanner_outlined, size: 18),
                        title: Text(isScanning
                            ? 'Escaneando...'
                            : 'Escanear tareas'),
                        onTap: isScanning
                            ? null
                            : () => context
                                .read<TasksBloc>()
                                .add(ScanTasks(project)),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final ProjectModel project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onManageAgents;
  final VoidCallback onToggleScheduler;

  const _ProjectTile({
    required this.project,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onManageAgents,
    required this.onToggleScheduler,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _hexToColor(project.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    project.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'agents',
                      child: Row(
                        children: [
                          Icon(Icons.smart_toy_outlined, size: 14),
                          SizedBox(width: 8),
                          Text('Gestionar agentes',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'scheduler',
                      child: Row(
                        children: [
                          Icon(
                            project.schedulerEnabled
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            project.schedulerEnabled
                                ? 'Excluir del scheduler'
                                : 'Incluir en scheduler',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Quitar de la lista',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'agents') onManageAgents();
                    if (v == 'scheduler') onToggleScheduler();
                    if (v == 'delete') onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
        if (isSelected) _FolderTree(project: project),
      ],
    );
  }
}

class _FolderTree extends StatelessWidget {
  final ProjectModel project;

  const _FolderTree({required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<FoldersBloc, FoldersState>(
      builder: (context, state) {
        final selectedId = state.selectedFolderId;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Todos" entry
            _FolderTile(
              label: 'Todos',
              icon: Icons.inbox_outlined,
              isSelected: selectedId == null,
              onTap: () =>
                  context.read<FoldersBloc>().add(const SelectFolder(null)),
            ),
            // Folder list
            ...state.folders.map((folder) => _FolderTile(
                  label: folder.name,
                  icon: Icons.folder_outlined,
                  isSelected: selectedId == folder.id,
                  onTap: () => context
                      .read<FoldersBloc>()
                      .add(SelectFolder(folder.id)),
                  trailing: PopupMenuButton<String>(
                    iconSize: 14,
                    padding: EdgeInsets.zero,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'attrs',
                        child: Row(children: [
                          Icon(Icons.tune, size: 14),
                          SizedBox(width: 8),
                          Text('Atributos', style: TextStyle(fontSize: 13)),
                        ]),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar',
                            style:
                                TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                    onSelected: (v) {
                      if (v == 'attrs') {
                        showDialog(
                          context: context,
                          builder: (_) => BlocProvider.value(
                            value: context.read<FoldersBloc>(),
                            child: FolderAttributesDialog(
                              folder: folder,
                              project: project,
                            ),
                          ),
                        );
                      }
                      if (v == 'delete') {
                        context.read<FoldersBloc>().add(
                            DeleteFolder(
                                project: project, folderId: folder.id));
                      }
                    },
                  ),
                )),
            // New folder button
            InkWell(
              onTap: () => _showCreateFolderDialog(context),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 5),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 13,
                        color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text('Nueva carpeta',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva carpeta'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nombre'),
          autofocus: true,
          onSubmitted: (_) {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              context
                  .read<FoldersBloc>()
                  .add(CreateFolder(project: project, name: name));
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context
                    .read<FoldersBloc>()
                    .add(CreateFolder(project: project, name: name));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _FolderTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 28, right: 4, top: 4, bottom: 4),
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
