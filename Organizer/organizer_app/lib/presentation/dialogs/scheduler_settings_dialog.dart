import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/runner_config.dart';
import '../blocs/projects/projects_bloc.dart';
import '../blocs/projects/projects_event.dart';
import '../blocs/projects/projects_state.dart';

class SchedulerSettingsDialog extends StatefulWidget {
  const SchedulerSettingsDialog({super.key});

  @override
  State<SchedulerSettingsDialog> createState() =>
      _SchedulerSettingsDialogState();
}

class _SchedulerSettingsDialogState extends State<SchedulerSettingsDialog> {
  late RunnerConfig _config;
  late bool _installed;
  late TextEditingController _intervalController;
  late TextEditingController _claudePathController;

  static const String _defaultClaudePath =
      '/Users/alex/.nvm/versions/node/v18.20.5/bin/claude';

  @override
  void initState() {
    super.initState();
    final state = context.read<ProjectsBloc>().state;
    _config = state.runnerConfig;
    _installed = state.runnerInstalled;
    _intervalController =
        TextEditingController(text: _config.intervalMinutes.toString());
    _claudePathController = TextEditingController(
      text: _config.claudePath.isEmpty ? _defaultClaudePath : _config.claudePath,
    );
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _claudePathController.dispose();
    super.dispose();
  }

  RunnerConfig _buildConfig({bool? enabled}) {
    final interval = int.tryParse(_intervalController.text) ?? 60;
    return _config.copyWith(
      enabled: enabled ?? _config.enabled,
      intervalMinutes: interval.clamp(1, 1440),
      claudePath: _claudePathController.text.trim(),
    );
  }

  void _install() {
    final config = _buildConfig(enabled: true);
    context.read<ProjectsBloc>().add(InstallRunner(config));
    setState(() {
      _config = config;
      _installed = true;
    });
  }

  void _uninstall() {
    context.read<ProjectsBloc>().add(const UninstallRunner());
    setState(() => _installed = false);
  }

  void _saveSettings() {
    final config = _buildConfig();
    context.read<ProjectsBloc>().add(SaveRunnerConfig(config));
    setState(() => _config = config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<ProjectsBloc, ProjectsState>(
      listenWhen: (prev, curr) =>
          curr.runnerInstalled != prev.runnerInstalled ||
          curr.runnerConfig != prev.runnerConfig,
      listener: (_, state) {
        setState(() {
          _installed = state.runnerInstalled;
          _config = state.runnerConfig;
        });
      },
      child: AlertDialog(
        title: const Text('Configuración del Scheduler'),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusRow(installed: _installed),
              const SizedBox(height: 20),
              Text('Ruta del CLI de Claude',
                  style: theme.textTheme.labelSmall),
              const SizedBox(height: 6),
              TextField(
                controller: _claudePathController,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: '/path/to/claude',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Intervalo (minutos)',
                            style: theme.textTheme.labelSmall),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _intervalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '60',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Habilitado',
                          style: theme.textTheme.labelSmall),
                      Switch(
                        value: _config.enabled,
                        onChanged: _installed
                            ? (v) {
                                final updated = _buildConfig(enabled: v);
                                context
                                    .read<ProjectsBloc>()
                                    .add(SaveRunnerConfig(updated));
                                setState(() => _config = updated);
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              if (_config.lastRun != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Última ejecución: ${_config.lastRun!.toLocal().toString().substring(0, 16)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          if (_installed) ...[
            OutlinedButton(
              onPressed: _saveSettings,
              child: const Text('Guardar ajustes'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error),
              onPressed: _uninstall,
              child: const Text('Desinstalar'),
            ),
          ] else
            ElevatedButton(
              onPressed: _install,
              child: const Text('Instalar daemon'),
            ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final bool installed;
  const _StatusRow({required this.installed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = installed ? Colors.green : theme.colorScheme.outline;
    final label = installed ? 'Daemon instalado' : 'Daemon no instalado';
    return Row(
      children: [
        Icon(
          installed ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
