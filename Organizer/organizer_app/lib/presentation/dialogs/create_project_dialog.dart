import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/projects/projects_bloc.dart';
import '../blocs/projects/projects_event.dart';
import '../blocs/projects/projects_state.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedColor = '#6366f1';
  String? _folderPath;
  bool _nameValid = false;

  static const List<String> _colors = [
    '#6366f1',
    '#3b82f6',
    '#22c55e',
    '#f59e0b',
    '#ef4444',
    '#ec4899',
    '#14b8a6',
    '#8b5cf6',
  ];

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  bool get _canSubmit => _nameValid && _folderPath != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      final valid = _nameController.text.trim().isNotEmpty;
      if (valid != _nameValid) setState(() => _nameValid = valid);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _pickFolder() {
    context.read<ProjectsBloc>().add(const PickProjectFolder());
  }

  void _submit() {
    if (!_canSubmit) return;

    context.read<ProjectsBloc>().add(CreateProject(
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          folderPath: _folderPath!,
          color: _selectedColor,
        ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProjectsBloc, ProjectsState>(
      listenWhen: (prev, curr) =>
          curr.pickedFolderPath != prev.pickedFolderPath &&
          curr.pickedFolderPath != null,
      listener: (context, state) {
        setState(() => _folderPath = state.pickedFolderPath);
      },
      child: AlertDialog(
        title: const Text('Nuevo Proyecto'),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del proyecto *',
                ),
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _folderPath ?? 'Sin carpeta seleccionada',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _pickFolder,
                    child: const Text('Seleccionar carpeta'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Color', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Row(
                children: _colors.map((hex) {
                  final selected = hex == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _hexToColor(hex),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color:
                                    Theme.of(context).colorScheme.onSurface,
                                width: 2,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
