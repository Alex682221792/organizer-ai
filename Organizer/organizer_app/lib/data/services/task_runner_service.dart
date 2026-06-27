import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../repositories/runner_config_repository.dart';
import '../../core/constants/app_constants.dart';

class TaskRunnerService {
  final RunnerConfigRepository _runnerConfigRepository;

  TaskRunnerService(this._runnerConfigRepository);

  Future<bool> runTask(TaskModel task, ProjectModel project) async {
    final config = await _runnerConfigRepository.load();
    if (config.claudePath.isEmpty || !File(config.claudePath).existsSync()) {
      throw Exception(
          'Claude CLI no encontrado. Configúralo en Ajustes del Scheduler.');
    }

    final taskDir =
        p.join(project.folderPath, AppConstants.tasksFolder, task.id);
    final metaFile = File(p.join(taskDir, AppConstants.taskMetaFile));
    final promptFile = File(p.join(taskDir, AppConstants.taskPromptFile));
    final agentPromptsFile =
        File(p.join(taskDir, AppConstants.agentPromptsFile));
    final obsDir = Directory(p.join(taskDir, AppConstants.obsFolder));

    if (!await promptFile.exists()) {
      throw Exception('task.md no encontrado para la tarea ${task.id}');
    }

    final taskContent = await promptFile.readAsString();

    Map<String, dynamic> agentPrompts = {};
    if (await agentPromptsFile.exists()) {
      try {
        agentPrompts = jsonDecode(await agentPromptsFile.readAsString())
            as Map<String, dynamic>;
      } catch (_) {}
    }

    // Mark as in_progress
    int currentRunCount = task.runCount;
    if (await metaFile.exists()) {
      try {
        final json =
            jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        currentRunCount = json['runCount'] as int? ?? 0;
        json['status'] = 'in_progress';
        json['updatedAt'] = DateTime.now().toIso8601String();
        await metaFile.writeAsString(jsonEncode(json));
      } catch (_) {}
    }

    if (!await obsDir.exists()) await obsDir.create(recursive: true);

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final nextRun = currentRunCount + 1;
    final obsFile =
        File(p.join(obsDir.path, 'run-$nextRun-$timestamp.md'));

    final agentIds =
        task.agentIds.isNotEmpty ? task.agentIds : <String>['default'];
    bool success = true;
    final buffer = StringBuffer();

    for (final agentId in agentIds) {
      final systemPrompt = agentPrompts[agentId] as String?;
      final fullPrompt =
          (systemPrompt != null && systemPrompt.isNotEmpty)
              ? '<system>\n$systemPrompt\n</system>\n\n$taskContent'
              : taskContent;

      try {
        final result = await Process.run(
          config.claudePath,
          ['--print', '--dangerously-skip-permissions', '-p', fullPrompt],
          workingDirectory: project.folderPath,
        ).timeout(const Duration(minutes: 10));

        final out = result.stdout as String;
        final err = result.stderr as String;

        if (agentIds.length > 1) buffer.writeln('## Agente: $agentId\n');
        buffer.writeln(out);

        if (result.exitCode != 0) {
          if (err.isNotEmpty) {
            buffer.writeln('\n[exit ${result.exitCode}] $err');
          }
          success = false;
        }
      } catch (e) {
        buffer.writeln('\n[error: $e]');
        success = false;
      }
    }

    await obsFile.writeAsString(buffer.toString());

    // Update meta with final status
    if (await metaFile.exists()) {
      try {
        final json =
            jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        json['status'] = success ? 'completed' : 'pending';
        json['runCount'] = currentRunCount + 1;
        json['updatedAt'] = DateTime.now().toIso8601String();
        await metaFile.writeAsString(jsonEncode(json));
      } catch (_) {}
    }

    return success;
  }
}
