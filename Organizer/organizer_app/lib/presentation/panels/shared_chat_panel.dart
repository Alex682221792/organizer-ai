import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/project_model.dart';
import '../../data/models/shared_chat_message.dart';
import '../../data/repositories/task_repository.dart';
import '../../injection_container.dart';

class SharedChatPanel extends StatefulWidget {
  final ProjectModel project;

  const SharedChatPanel({super.key, required this.project});

  @override
  State<SharedChatPanel> createState() => _SharedChatPanelState();
}

class _SharedChatPanelState extends State<SharedChatPanel> {
  final _taskRepository = getIt<TaskRepository>();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  List<SharedChatMessage> _messages = [];
  bool _loading = true;
  SharedChatMessageType _selectedType = SharedChatMessageType.note;
  String? _filterTaskId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void didUpdateWidget(SharedChatPanel old) {
    super.didUpdateWidget(old);
    if (old.project.id != widget.project.id) {
      _filterTaskId = null;
      _load();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final messages = await _taskRepository.loadSharedChat(widget.project);
    if (mounted) {
      setState(() {
        _messages = messages;
        _loading = false;
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

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final msg = SharedChatMessage(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      role: 'user',
      agentName: 'Usuario',
      taskId: _filterTaskId,
      type: _selectedType,
      content: text,
    );
    _messageController.clear();
    await _taskRepository.appendSharedChatMessage(widget.project, msg);
    await _load();
  }

  List<SharedChatMessage> get _filtered => _filterTaskId == null
      ? _messages
      : _messages.where((m) => m.taskId == _filterTaskId).toList();

  Set<String> get _taskIds {
    final ids = <String>{};
    for (final m in _messages) {
      if (m.taskId != null) ids.add(m.taskId!);
    }
    return ids;
  }

  Map<String, String> get _taskTitles {
    final map = <String, String>{};
    for (final m in _messages) {
      if (m.taskId != null && m.taskTitle != null) {
        map[m.taskId!] = m.taskTitle!;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final taskTitles = _taskTitles;

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(left: BorderSide(color: theme.dividerColor)),
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
            child: Row(
              children: [
                Icon(Icons.forum_outlined,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Chat General',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: _load,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
          ),
          // Task filter chips
          if (_taskIds.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todos',
                    selected: _filterTaskId == null,
                    onTap: () => setState(() => _filterTaskId = null),
                  ),
                  const SizedBox(width: 4),
                  ..._taskIds.map((id) {
                    final title = taskTitles[id] ?? id.substring(0, 8);
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _FilterChip(
                        label: title,
                        selected: _filterTaskId == id,
                        onTap: () => setState(() => _filterTaskId = id),
                        maxWidth: 100,
                      ),
                    );
                  }),
                ],
              ),
            ),
          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Sin mensajes aún.\nLos agentes escriben aquí sus observaciones.',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(10),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _SharedMessageTile(
                          message: filtered[i],
                          showTaskBadge: _filterTaskId == null,
                        ),
                      ),
          ),
          // Input
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
                              child: _TypeChip(
                                type: t,
                                selected: _selectedType == t,
                                onTap: () =>
                                    setState(() => _selectedType = t),
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
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: _send,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedMessageTile extends StatelessWidget {
  final SharedChatMessage message;
  final bool showTaskBadge;

  const _SharedMessageTile({
    required this.message,
    required this.showTaskBadge,
  });

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
    final isSystem = message.role == 'system';
    final typeColor = message.type.color(cs);

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            message.content,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.outline,
              fontStyle: FontStyle.italic,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Meta row
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Icon(message.type.icon, size: 11, color: typeColor),
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
              if (showTaskBadge && message.taskTitle != null) ...[
                const SizedBox(width: 4),
                Container(
                  constraints: const BoxConstraints(maxWidth: 90),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    message.taskTitle!,
                    style: TextStyle(fontSize: 9, color: cs.secondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (isUser) ...[
                const SizedBox(width: 4),
                Text(message.agentName,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: cs.primary)),
                const SizedBox(width: 3),
                Icon(message.type.icon, size: 11, color: cs.primary),
              ],
              const SizedBox(width: 4),
              Text(_timeAgo(message.timestamp),
                  style: TextStyle(fontSize: 9, color: cs.outline)),
            ],
          ),
          const SizedBox(height: 3),
          // Bubble
          Align(
            alignment:
                isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 290),
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
                  color: isUser ? Colors.white : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? maxWidth;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth!) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.15)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: cs.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: selected ? cs.primary : cs.secondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final SharedChatMessageType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = type.color(cs);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: color.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 10, color: selected ? color : cs.outline),
            const SizedBox(width: 3),
            Text(
              type.displayName,
              style: TextStyle(
                fontSize: 10,
                color: selected ? color : cs.outline,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
