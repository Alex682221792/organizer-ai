import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/folder_model.dart';
import '../../data/models/project_model.dart';
import '../blocs/folders/folders_bloc.dart';
import '../blocs/folders/folders_event.dart';

class FolderAttributesDialog extends StatefulWidget {
  final FolderModel folder;
  final ProjectModel project;

  const FolderAttributesDialog({
    super.key,
    required this.folder,
    required this.project,
  });

  @override
  State<FolderAttributesDialog> createState() => _FolderAttributesDialogState();
}

class _FolderAttributesDialogState extends State<FolderAttributesDialog> {
  late List<_AttrEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.folder.attributes.entries
        .map((e) => _AttrEntry(key: e.key, value: e.value))
        .toList();
  }

  void _addEntry() {
    setState(() => _entries.add(_AttrEntry()));
  }

  void _removeEntry(int i) {
    setState(() => _entries.removeAt(i));
  }

  void _save() {
    final attrs = <String, String>{};
    for (final e in _entries) {
      final k = e.keyController.text.trim();
      final v = e.valueController.text.trim();
      if (k.isNotEmpty) attrs[k] = v;
    }
    context.read<FoldersBloc>().add(UpdateFolder(
          project: widget.project,
          folder: widget.folder.copyWith(attributes: attrs),
        ));
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Atributos — ${widget.folder.name}'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sin atributos. Agregá uno con el botón +',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ..._entries.asMap().entries.map((entry) {
              final i = entry.key;
              final attr = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: attr.keyController,
                        decoration: const InputDecoration(
                          labelText: 'Clave',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: attr.valueController,
                        decoration: InputDecoration(
                          labelText: 'Valor',
                          isDense: true,
                          suffixIcon: attr.keyController.text == 'working_dir'
                              ? IconButton(
                                  icon: const Icon(Icons.folder_open, size: 16),
                                  tooltip: 'Seleccionar carpeta',
                                  onPressed: () async {
                                    final result = await FilePicker.platform
                                        .getDirectoryPath();
                                    if (result != null) {
                                      setState(() => attr.valueController.text =
                                          result);
                                    }
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => _removeEntry(i),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar atributo'),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: theme.colorScheme.secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'working_dir define el directorio de trabajo para Claude al ejecutar tareas de esta carpeta.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
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
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _AttrEntry {
  final TextEditingController keyController;
  final TextEditingController valueController;

  _AttrEntry({String key = '', String value = ''})
      : keyController = TextEditingController(text: key),
        valueController = TextEditingController(text: value);

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}
