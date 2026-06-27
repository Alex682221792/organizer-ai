import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/project_model.dart';
import '../../data/services/refinement_service.dart';
import '../../injection_container.dart';
import '../blocs/agents/agents_bloc.dart';
import '../blocs/folders/folders_bloc.dart';
import '../blocs/folders/folders_state.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../blocs/tasks/tasks_event.dart';

class CreateTaskDialog extends StatefulWidget {
  final ProjectModel project;

  const CreateTaskDialog({super.key, required this.project});

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  String? _selectedFolderId;
  bool _canSubmit = false;
  bool _isRefining = false;
  RefinementResult? _refinementResult;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = context.read<FoldersBloc>().state.selectedFolderId;
    _titleController.addListener(_onInputChanged);
    _instructionsController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final canSubmit = _titleController.text.trim().isNotEmpty;
    final hasChanged = _titleController.text.trim() != _lastRefinedTitle ||
        _instructionsController.text.trim() != _lastRefinedInstructions;
    if (canSubmit != _canSubmit || (hasChanged && _refinementResult != null)) {
      setState(() {
        _canSubmit = canSubmit;
        if (hasChanged) _refinementResult = null;
      });
    }
  }

  String _lastRefinedTitle = '';
  String _lastRefinedInstructions = '';

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _refine() async {
    if (!_canSubmit || _isRefining) return;
    final agents = context.read<AgentsBloc>().state.agents;
    setState(() {
      _isRefining = true;
      _refinementResult = null;
    });
    _lastRefinedTitle = _titleController.text.trim();
    _lastRefinedInstructions = _instructionsController.text.trim();
    final result = await getIt<RefinementService>().refine(
      title: _lastRefinedTitle,
      instructions: _lastRefinedInstructions,
      agents: agents,
    );
    if (mounted) {
      setState(() {
        _isRefining = false;
        _refinementResult = result;
      });
    }
  }

  void _submit() {
    if (!_canSubmit) return;
    final agents = context.read<AgentsBloc>().state.agents;
    context.read<TasksBloc>().add(CreateTask(
          project: widget.project,
          title: _titleController.text.trim(),
          instructions: _instructionsController.text.trim(),
          agents: agents,
          folderId: _selectedFolderId,
          refinementResult: _refinementResult,
        ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Nueva Tarea'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título *'),
                autofocus: true,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Instrucciones',
                  hintText:
                      'Describí qué debe hacer el agente con esta tarea...',
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Las instrucciones se guardarán como el prompt del agente en task.md',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isRefining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton.icon(
                          onPressed: _canSubmit ? _refine : null,
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text('Refinar'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                ],
              ),
              if (_refinementResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_fix_high,
                              size: 14, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Vista previa del refinamiento',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colorScheme.primary),
                          ),
                          if (_refinementResult!.agentIds.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Agentes: ${_refinementResult!.agentIds.join(", ")}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: colorScheme.onSurfaceVariant),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: SingleChildScrollView(
                          child: Text(
                            _refinementResult!.taskMd,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    fontFamily: 'monospace',
                                    color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              BlocBuilder<FoldersBloc, FoldersState>(
                builder: (context, foldersState) {
                  if (foldersState.folders.isEmpty) return const SizedBox();
                  return DropdownButtonFormField<String?>(
                    value: _selectedFolderId,
                    decoration: const InputDecoration(labelText: 'Carpeta'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sin carpeta'),
                      ),
                      ...foldersState.folders.map((f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(f.name),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selectedFolderId = v),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(_refinementResult != null ? 'Crear con refinamiento' : 'Crear'),
        ),
      ],
    );
  }
}
