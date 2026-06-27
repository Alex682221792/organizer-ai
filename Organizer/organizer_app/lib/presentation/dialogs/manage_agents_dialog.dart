import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/agent_model.dart';
import '../../data/models/project_model.dart';
import '../blocs/agents/agents_bloc.dart';
import '../blocs/agents/agents_event.dart';
import '../blocs/agents/agents_state.dart';

class ManageAgentsDialog extends StatelessWidget {
  final ProjectModel project;

  const ManageAgentsDialog({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentsBloc, AgentsState>(
      builder: (context, state) {
        return Dialog(
          child: SizedBox(
            width: 560,
            height: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(project: project),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(state.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : state.agents.isEmpty
                          ? const Center(
                              child: Text('Sin agentes. Crea uno con el botón +',
                                  style: TextStyle(fontSize: 13)))
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: state.agents.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) => _AgentTile(
                                agent: state.agents[i],
                                project: project,
                              ),
                            ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Nuevo agente'),
                        onPressed: () => _showAgentForm(context, project),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final ProjectModel project;

  const _Header({required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          const Icon(Icons.smart_toy_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Agentes — ${project.name}',
                style: theme.textTheme.titleMedium),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  final AgentModel agent;
  final ProjectModel project;

  const _AgentTile({required this.agent, required this.project});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        child: Icon(Icons.smart_toy_outlined,
            size: 16, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(agent.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(
        '${agent.model}  ·  ${agent.tools.isEmpty ? "sin tools" : agent.tools.join(", ")}',
        style: const TextStyle(fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: () => _showAgentForm(context, project, agent: agent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            onPressed: () => context
                .read<AgentsBloc>()
                .add(DeleteAgent(project: project, agentId: agent.id)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

void _showAgentForm(BuildContext context, ProjectModel project,
    {AgentModel? agent}) {
  showDialog(
    context: context,
    builder: (dialogContext) => BlocProvider.value(
      value: context.read<AgentsBloc>(),
      child: _AgentFormDialog(project: project, existing: agent),
    ),
  );
}

class _AgentFormDialog extends StatefulWidget {
  final ProjectModel project;
  final AgentModel? existing;

  const _AgentFormDialog({required this.project, this.existing});

  @override
  State<_AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends State<_AgentFormDialog> {
  final _nameController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedModel = kAvailableModels[1]; // sonnet default
  final Set<String> _selectedTools = {};
  bool _isSaving = false;
  // Stored separately so it persists after _isSaving resets
  String? _saveError;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final a = widget.existing!;
      _nameController.text = a.name;
      _systemPromptController.text = a.systemPrompt ?? '';
      _descriptionController.text = a.description;
      _selectedModel = a.model;
      _selectedTools.addAll(a.tools);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _systemPromptController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final sp = _systemPromptController.text.trim();
    if (widget.existing != null) {
      context.read<AgentsBloc>().add(UpdateAgent(
            project: widget.project,
            agent: widget.existing!.copyWith(
              name: name,
              model: _selectedModel,
              systemPrompt: sp.isEmpty ? null : sp,
              tools: _selectedTools.toList(),
              description: _descriptionController.text.trim(),
            ),
          ));
    } else {
      context.read<AgentsBloc>().add(CreateAgent(
            project: widget.project,
            name: name,
            model: _selectedModel,
            systemPrompt: sp.isEmpty ? null : sp,
            tools: _selectedTools.toList(),
            description: _descriptionController.text.trim(),
          ));
    }
    // Don't pop here — BlocConsumer listener handles it
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return BlocConsumer<AgentsBloc, AgentsState>(
      listenWhen: (prev, curr) =>
          _isSaving && prev.isLoading && !curr.isLoading,
      listener: (context, state) {
        if (state.error != null) {
          // Store error separately before resetting _isSaving so builder can show it
          setState(() {
            _saveError = state.error;
            _isSaving = false;
          });
        } else {
          Navigator.pop(context);
        }
      },
      builder: (context, state) {
        final isLoading = _isSaving && state.isLoading;
        return AlertDialog(
          title: Text(isEditing ? 'Editar agente' : 'Nuevo agente',
              style: const TextStyle(fontSize: 16)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_saveError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _saveError!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _nameController,
                    enabled: !isLoading,
                    decoration:
                        const InputDecoration(labelText: 'Nombre', isDense: true),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                        labelText: 'Descripción (para el refinamiento)',
                        isDense: true),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedModel,
                    decoration:
                        const InputDecoration(labelText: 'Modelo', isDense: true),
                    style: const TextStyle(fontSize: 13),
                    items: kAvailableModels
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: isLoading
                        ? null
                        : (v) => setState(() => _selectedModel = v!),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tools habilitadas',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: kAvailableTools.map((tool) {
                      final selected = _selectedTools.contains(tool);
                      return FilterChip(
                        label: Text(tool, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: isLoading
                            ? null
                            : (v) => setState(() => v
                                ? _selectedTools.add(tool)
                                : _selectedTools.remove(tool)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _systemPromptController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                        labelText:
                            'System prompt (opcional — se genera automáticamente)',
                        isDense: true,
                        border: OutlineInputBorder()),
                    style:
                        const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    maxLines: 5,
                    minLines: 3,
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Generando system prompt con Claude…',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : _save,
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        );
      },
    );
  }
}
