import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/agent_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/task_status.dart';
import '../../data/models/shared_chat_message.dart';
import '../../data/repositories/task_repository.dart';
import 'package:uuid/uuid.dart';
import '../../injection_container.dart';
import '../blocs/agents/agents_bloc.dart';
import '../blocs/agents/agents_state.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../blocs/tasks/tasks_event.dart';
import '../blocs/tasks/tasks_state.dart';
import '../../data/models/folder_model.dart';
import '../blocs/folders/folders_bloc.dart';
import '../blocs/folders/folders_state.dart';
import '../blocs/projects/projects_state.dart';
import '../blocs/projects/projects_bloc.dart';

class TaskDetailPanel extends StatefulWidget {
  final TaskModel task;
  final ProjectModel project;

  const TaskDetailPanel({
    super.key,
    required this.task,
    required this.project,
  });

  @override
  State<TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends State<TaskDetailPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _taskRepository = getIt<TaskRepository>();

  // Prompt tab state
  String _promptContent = '';
  bool _editingPrompt = false;
  late TextEditingController _promptEditController;
  bool _loadingPrompt = true;

  // Observations tab state
  List<String> _observations = [];
  bool _loadingObs = true;

  // Thread tab state (shared chat filtered by task)
  List<SharedChatMessage> _messages = [];
  bool _loadingThread = true;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  SharedChatMessageType _selectedType = SharedChatMessageType.note;
  final _uuid = const Uuid();

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _promptEditController = TextEditingController();
    _loadAll();
    _updatePolling(widget.task);
  }

  @override
  void didUpdateWidget(TaskDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.task.id != widget.task.id) {
      _editingPrompt = false;
      _loadAll();
    } else if (old.task.runCount != widget.task.runCount) {
      _loadObs();
      _loadSharedMessages();
    }
    _updatePolling(widget.task);
  }

  void _updatePolling(TaskModel task) {
    _pollTimer?.cancel();
    if (task.status == TaskStatus.inProgress) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        await _loadSharedMessages();
        final fresh = await _taskRepository.reloadTask(widget.task, widget.project);
        if (fresh != null && fresh.status != widget.task.status && mounted) {
          context.read<TasksBloc>().add(LoadTasks(widget.project));
        }
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    _promptEditController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPrompt(), _loadObs(), _loadSharedMessages()]);
  }

  Future<void> _loadPrompt() async {
    setState(() => _loadingPrompt = true);
    final content =
        await _taskRepository.readTaskPrompt(widget.task, widget.project);
    if (mounted) {
      setState(() {
        _promptContent = content;
        _promptEditController.text = content;
        _loadingPrompt = false;
      });
    }
  }

  Future<void> _loadObs() async {
    setState(() => _loadingObs = true);
    final obs =
        await _taskRepository.loadObservations(widget.task, widget.project);
    if (mounted) {
      setState(() {
        _observations = obs;
        _loadingObs = false;
      });
    }
  }

  Future<void> _loadSharedMessages() async {
    setState(() => _loadingThread = true);
    final all = await _taskRepository.loadSharedChat(widget.project);
    if (mounted) {
      setState(() {
        _messages = all.where((m) => m.taskId == widget.task.id).toList();
        _loadingThread = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _savePrompt() async {
    await _taskRepository.writeTaskPrompt(
        widget.task, widget.project, _promptEditController.text);
    setState(() {
      _promptContent = _promptEditController.text;
      _editingPrompt = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final msg = SharedChatMessage(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      role: 'user',
      agentName: 'Usuario',
      taskId: widget.task.id,
      taskTitle: widget.task.title,
      type: _selectedType,
      content: text,
    );
    _messageController.clear();

    await _taskRepository.appendSharedChatMessage(widget.project, msg);
    await _loadSharedMessages();
  }

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

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(
          left: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.task.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => context
                          .read<TasksBloc>()
                          .add(const ClearSelectedTask()),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BlocBuilder<ProjectsBloc, ProjectsState>(
                  builder: (context, projState) {
                    final project = projState.selectedProject ?? widget.project;
                    return DropdownButton<TaskStatus>(
                      value: widget.task.status,
                      isDense: true,
                      underline: const SizedBox(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(widget.task.status),
                        fontWeight: FontWeight.w500,
                      ),
                      items: TaskStatus.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(
                            s.displayName,
                            style: TextStyle(
                              color: _statusColor(s),
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newStatus) {
                        if (newStatus != null) {
                          context.read<TasksBloc>().add(UpdateTaskStatus(
                                task: widget.task,
                                project: project,
                                newStatus: newStatus,
                              ));
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                BlocBuilder<AgentsBloc, AgentsState>(
                  builder: (context, agentsState) {
                    return _AgentsRow(
                      task: widget.task,
                      project: widget.project,
                      availableAgents: agentsState.agents,
                    );
                  },
                ),
                const SizedBox(height: 4),
                BlocBuilder<TasksBloc, TasksState>(
                  builder: (context, tasksState) {
                    final allTasks = tasksState.tasksByStatus.values
                        .expand((list) => list)
                        .where((t) => t.id != widget.task.id)
                        .toList();
                    return _DependenciesRow(
                      task: widget.task,
                      project: widget.project,
                      allTasks: allTasks,
                    );
                  },
                ),
                const SizedBox(height: 4),
                _RunInfoRow(task: widget.task),
                const SizedBox(height: 8),
                BlocBuilder<TasksBloc, TasksState>(
                  builder: (context, tasksState) {
                    final isRunning =
                        tasksState.isTaskRunning(widget.task.id);
                    final isInProgress =
                        widget.task.status == TaskStatus.inProgress;
                    final busy = isRunning || isInProgress;
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: busy
                            ? null
                            : () => context.read<TasksBloc>().add(
                                  RunTaskNow(
                                    task: widget.task,
                                    project: widget.project,
                                  ),
                                ),
                        icon: busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow, size: 16),
                        label: Text(
                          busy ? 'Ejecutando...' : 'Ejecutar ahora',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                BlocBuilder<FoldersBloc, FoldersState>(
                  builder: (context, foldersState) {
                    final folder = widget.task.folderId != null
                        ? foldersState.folders
                            .where((f) => f.id == widget.task.folderId)
                            .firstOrNull
                        : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FolderRow(
                          task: widget.task,
                          project: widget.project,
                          folders: foldersState.folders,
                        ),
                        if (folder != null)
                          _FolderAttributesBadge(folder: folder),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelStyle: const TextStyle(fontSize: 12),
            tabs: const [
              Tab(text: 'Prompt'),
              Tab(text: 'Observaciones'),
              Tab(text: 'Conversación'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPromptTab(theme),
                _buildObsTab(theme),
                _buildThreadTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptTab(ThemeData theme) {
    if (_loadingPrompt) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              const Spacer(),
              if (_editingPrompt) ...[
                TextButton(
                  onPressed: () => setState(() => _editingPrompt = false),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: _savePrompt,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Guardar'),
                ),
              ] else
                TextButton(
                  onPressed: () {
                    _promptEditController.text = _promptContent;
                    setState(() => _editingPrompt = true);
                  },
                  child: const Text('Editar', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        Expanded(
          child: _editingPrompt
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _promptEditController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _promptContent.isEmpty
                      ? Text(
                          'Sin prompt. Haz clic en Editar para agregar uno.',
                          style: theme.textTheme.bodySmall,
                        )
                      : SelectableText(
                          _promptContent,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildObsTab(ThemeData theme) {
    if (_loadingObs) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_observations.isEmpty) {
      return Center(
        child: Text('Sin observaciones aún.', style: theme.textTheme.bodySmall),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _observations.length,
      itemBuilder: (_, i) {
        final parts = _observations[i].split('\n\n');
        final filename = parts.isNotEmpty ? parts[0] : 'Archivo ${i + 1}';
        final content = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';

        return ExpansionTile(
          title: Text(filename, style: const TextStyle(fontSize: 12)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          children: [
            SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThreadTab(ThemeData theme) {
    final cs = theme.colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              if (widget.task.status == TaskStatus.inProgress) ...[
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text('En ejecución',
                    style: TextStyle(fontSize: 11, color: cs.primary)),
              ] else
                Text('${_messages.length} mensaje(s)',
                    style:
                        theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: _loadSharedMessages,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Actualizar',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingThread
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2))
              : _messages.isEmpty
                  ? Center(
                      child: Text('Sin mensajes aún.',
                          style: theme.textTheme.bodySmall))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(10),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) =>
                          _SharedTaskMessageBubble(message: _messages[i]),
                    ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: SharedChatMessageType.values
                      .where((t) => t != SharedChatMessageType.system)
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedType = t),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _selectedType == t
                                      ? t.color(cs).withValues(alpha: 0.15)
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                  border: _selectedType == t
                                      ? Border.all(
                                          color: t
                                              .color(cs)
                                              .withValues(alpha: 0.5))
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(t.icon,
                                        size: 10,
                                        color: _selectedType == t
                                            ? t.color(cs)
                                            : cs.outline),
                                    const SizedBox(width: 3),
                                    Text(
                                      t.displayName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _selectedType == t
                                            ? t.color(cs)
                                            : cs.outline,
                                        fontWeight: _selectedType == t
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: TextStyle(fontSize: 12),
                      ),
                      style: const TextStyle(fontSize: 12),
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, size: 18),
                    onPressed: _sendMessage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SharedTaskMessageBubble extends StatelessWidget {
  final SharedChatMessage message;

  const _SharedTaskMessageBubble({required this.message});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUser = message.role == 'user';
    final typeColor = message.type.color(cs);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Icon(message.type.icon, size: 10, color: typeColor),
                const SizedBox(width: 3),
                Text(message.agentName,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: typeColor)),
                const SizedBox(width: 4),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(message.type.displayName,
                    style: TextStyle(fontSize: 9, color: typeColor)),
              ),
              if (isUser) ...[
                const SizedBox(width: 4),
                Text('Usuario',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: cs.primary)),
              ],
              const SizedBox(width: 4),
              Text(_timeAgo(message.timestamp),
                  style: TextStyle(fontSize: 9, color: cs.outline)),
            ],
          ),
          const SizedBox(height: 3),
          Align(
            alignment:
                isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isUser ? cs.primary : cs.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10),
                  topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(isUser ? 10 : 2),
                  bottomRight: Radius.circular(isUser ? 2 : 10),
                ),
                border: isUser ? null : Border.all(color: theme.dividerColor),
              ),
              child: SelectableText(
                message.content,
                style: TextStyle(
                  fontSize: 12,
                  color: isUser
                      ? Colors.white
                      : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentsRow extends StatelessWidget {
  final TaskModel task;
  final ProjectModel project;
  final List<AgentModel> availableAgents;

  const _AgentsRow({
    required this.task,
    required this.project,
    required this.availableAgents,
  });

  void _showPicker(BuildContext context) {
    final assigned = Set<String>.from(task.agentIds);
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<TasksBloc>(),
        child: _AgentPickerDialog(
          task: task,
          project: project,
          availableAgents: availableAgents,
          assignedIds: assigned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assigned =
        availableAgents.where((a) => task.agentIds.contains(a.id)).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.smart_toy_outlined,
            size: 13, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: assigned.isEmpty
              ? Text('Sin agentes asignados',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11))
              : Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: assigned
                      .map((a) => Chip(
                            label: Text(a.name,
                                style: const TextStyle(fontSize: 10)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
        ),
        if (availableAgents.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 14),
            onPressed: () => _showPicker(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Asignar agentes',
          ),
      ],
    );
  }
}

class _AgentPickerDialog extends StatefulWidget {
  final TaskModel task;
  final ProjectModel project;
  final List<AgentModel> availableAgents;
  final Set<String> assignedIds;

  const _AgentPickerDialog({
    required this.task,
    required this.project,
    required this.availableAgents,
    required this.assignedIds,
  });

  @override
  State<_AgentPickerDialog> createState() => _AgentPickerDialogState();
}

class _AgentPickerDialogState extends State<_AgentPickerDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.assignedIds);
  }

  void _save() {
    context.read<TasksBloc>().add(UpdateTaskAgents(
          task: widget.task,
          project: widget.project,
          agentIds: _selected.toList(),
        ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asignar agentes', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.availableAgents.map((agent) {
            return CheckboxListTile(
              dense: true,
              value: _selected.contains(agent.id),
              title: Text(agent.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(agent.description,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis),
              onChanged: (v) => setState(() =>
                  v! ? _selected.add(agent.id) : _selected.remove(agent.id)),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _DependenciesRow extends StatelessWidget {
  final TaskModel task;
  final ProjectModel project;
  final List<TaskModel> allTasks;

  const _DependenciesRow({
    required this.task,
    required this.project,
    required this.allTasks,
  });

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<TasksBloc>(),
        child: _DependencyPickerDialog(
          task: task,
          project: project,
          allTasks: allTasks,
          selectedIds: Set<String>.from(task.blockedBy),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blockers =
        allTasks.where((t) => task.blockedBy.contains(t.id)).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.link, size: 13, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 6),
        Expanded(
          child: blockers.isEmpty
              ? Text('Sin dependencias',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11))
              : Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: blockers
                      .map((t) => Chip(
                            label: Text(t.title,
                                style: const TextStyle(fontSize: 10)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 14),
          onPressed: () => _showPicker(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Definir dependencias',
        ),
      ],
    );
  }
}

class _DependencyPickerDialog extends StatefulWidget {
  final TaskModel task;
  final ProjectModel project;
  final List<TaskModel> allTasks;
  final Set<String> selectedIds;

  const _DependencyPickerDialog({
    required this.task,
    required this.project,
    required this.allTasks,
    required this.selectedIds,
  });

  @override
  State<_DependencyPickerDialog> createState() =>
      _DependencyPickerDialogState();
}

class _DependencyPickerDialogState extends State<_DependencyPickerDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedIds);
  }

  void _save() {
    context.read<TasksBloc>().add(UpdateTaskDependencies(
          task: widget.task,
          project: widget.project,
          blockedBy: _selected.toList(),
        ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bloqueado por...', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 340,
        child: widget.allTasks.isEmpty
            ? const Text('No hay otras tareas en este proyecto.',
                style: TextStyle(fontSize: 13))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.allTasks.map((t) {
                  return CheckboxListTile(
                    dense: true,
                    value: _selected.contains(t.id),
                    title: Text(t.title, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(t.status.displayName,
                        style: const TextStyle(fontSize: 11)),
                    onChanged: (v) => setState(() =>
                        v! ? _selected.add(t.id) : _selected.remove(t.id)),
                  );
                }).toList(),
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _RunInfoRow extends StatelessWidget {
  final TaskModel task;

  const _RunInfoRow({required this.task});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (task.runCount == 0) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.history, size: 13, color: theme.colorScheme.secondary),
        const SizedBox(width: 6),
        Text(
          'Ejecución #${task.runCount} · ${_timeAgo(task.updatedAt)}',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _FolderRow extends StatelessWidget {
  final TaskModel task;
  final ProjectModel project;
  final List<FolderModel> folders;

  const _FolderRow({
    required this.task,
    required this.project,
    required this.folders,
  });

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<TasksBloc>(),
        child: _FolderPickerDialog(
          task: task,
          project: project,
          folders: folders,
          currentFolderId: task.folderId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folder = task.folderId != null
        ? folders.where((f) => f.id == task.folderId).firstOrNull
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.folder_outlined,
            size: 13, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            folder?.name ?? 'Sin carpeta',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 14),
          onPressed: () => _showPicker(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Cambiar carpeta',
        ),
      ],
    );
  }
}

class _FolderPickerDialog extends StatefulWidget {
  final TaskModel task;
  final ProjectModel project;
  final List<FolderModel> folders;
  final String? currentFolderId;

  const _FolderPickerDialog({
    required this.task,
    required this.project,
    required this.folders,
    this.currentFolderId,
  });

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentFolderId;
  }

  void _save() {
    context.read<TasksBloc>().add(UpdateTaskFolder(
          task: widget.task,
          project: widget.project,
          folderId: _selected,
        ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Carpeta', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              dense: true,
              value: null,
              groupValue: _selected,
              title:
                  const Text('Sin carpeta', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _selected = v),
            ),
            ...widget.folders.map((f) => RadioListTile<String?>(
                  dense: true,
                  value: f.id,
                  groupValue: _selected,
                  title: Text(f.name, style: const TextStyle(fontSize: 13)),
                  onChanged: (v) => setState(() => _selected = v),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _FolderAttributesBadge extends StatelessWidget {
  final FolderModel folder;

  const _FolderAttributesBadge({required this.folder});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attrs = folder.attributes;
    if (attrs.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined,
              size: 13, color: theme.colorScheme.secondary),
          const SizedBox(width: 5),
          Text(
            folder.name,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attrs.entries.map((e) => '${e.key}: ${e.value}').join('  ·  '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
