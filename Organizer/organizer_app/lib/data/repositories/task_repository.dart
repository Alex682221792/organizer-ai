import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/folder_model.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/task_status.dart';
import '../models/shared_chat_message.dart';
import '../models/thread_message.dart';
import '../../core/constants/app_constants.dart';

class TaskRepository {
  final _uuid = const Uuid();

  Future<List<FolderModel>> _loadFolders(ProjectModel project) async {
    try {
      final file = File(p.join(project.folderPath, AppConstants.foldersFile));
      if (!await file.exists()) return [];
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return list.map((e) => FolderModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  String _taskFolder(TaskModel task, ProjectModel project) =>
      p.join(project.folderPath, AppConstants.tasksFolder, task.id);

  Future<List<TaskModel>> loadTasks(ProjectModel project) async {
    try {
      final tasksDir = Directory(p.join(project.folderPath, AppConstants.tasksFolder));
      if (!await tasksDir.exists()) return [];

      final tasks = <TaskModel>[];
      await for (final entry in tasksDir.list()) {
        if (entry is Directory) {
          try {
            final metaFile = File(p.join(entry.path, AppConstants.taskMetaFile));
            if (await metaFile.exists()) {
              final content = await metaFile.readAsString();
              final json = jsonDecode(content) as Map<String, dynamic>;
              tasks.add(TaskModel.fromJson(json, project.id));
            }
          } catch (_) {
            // Skip malformed tasks
          }
        }
      }

      tasks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return tasks;
    } catch (e) {
      throw Exception('Failed to load tasks: $e');
    }
  }

  Future<TaskModel> createTask({
    required ProjectModel project,
    required String title,
    required String instructions,
    List<String> agentIds = const [],
    Map<String, String> agentSystemPrompts = const {},
    String? refinedTaskMd,
    String? folderId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      final taskDir = Directory(p.join(project.folderPath, AppConstants.tasksFolder, id));
      await taskDir.create(recursive: true);

      final obsDir = Directory(p.join(taskDir.path, AppConstants.obsFolder));
      await obsDir.create();

      final task = TaskModel(
        id: id,
        projectId: project.id,
        title: title,
        status: TaskStatus.backlog,
        instructions: instructions,
        createdAt: now,
        updatedAt: now,
        runCount: 0,
        needsInput: false,
        agentIds: agentIds,
        folderId: folderId,
      );

      final metaFile = File(p.join(taskDir.path, AppConstants.taskMetaFile));
      await metaFile.writeAsString(jsonEncode(task.toJson()));

      final promptFile = File(p.join(taskDir.path, AppConstants.taskPromptFile));
      await promptFile.writeAsString(refinedTaskMd?.isNotEmpty == true ? refinedTaskMd! : instructions);

      if (agentSystemPrompts.isNotEmpty) {
        final agentPromptsFile = File(p.join(taskDir.path, AppConstants.agentPromptsFile));
        await agentPromptsFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(agentSystemPrompts),
        );
      }

      await _syncQueue(project);
      return task;
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  Future<void> updateTaskStatus(
      TaskModel task, ProjectModel project, TaskStatus newStatus) async {
    try {
      final taskDir = _taskFolder(task, project);
      final metaFile = File(p.join(taskDir, AppConstants.taskMetaFile));

      if (!await metaFile.exists()) {
        throw Exception('Task meta file not found');
      }

      final content = await metaFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      json['status'] = newStatus.jsonValue;
      json['updatedAt'] = DateTime.now().toIso8601String();
      await metaFile.writeAsString(jsonEncode(json));

      await _syncQueue(project);
    } catch (e) {
      throw Exception('Failed to update task status: $e');
    }
  }

  Future<TaskModel> updateTaskAgents(
      TaskModel task, ProjectModel project, List<String> agentIds) async {
    try {
      final taskDir = _taskFolder(task, project);
      final metaFile = File(p.join(taskDir, AppConstants.taskMetaFile));

      if (!await metaFile.exists()) {
        throw Exception('Task meta file not found');
      }

      final content = await metaFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      json['agentIds'] = agentIds;
      json['updatedAt'] = DateTime.now().toIso8601String();
      await metaFile.writeAsString(jsonEncode(json));

      await _syncQueue(project);
      return task.copyWith(agentIds: agentIds, updatedAt: DateTime.now());
    } catch (e) {
      throw Exception('Failed to update task agents: $e');
    }
  }

  Future<TaskModel> updateTaskFolder(
      TaskModel task, ProjectModel project, String? folderId) async {
    try {
      final taskDir = _taskFolder(task, project);
      final metaFile = File(p.join(taskDir, AppConstants.taskMetaFile));
      if (!await metaFile.exists()) throw Exception('Task meta file not found');
      final json = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      if (folderId != null) {
        json['folderId'] = folderId;
      } else {
        json.remove('folderId');
      }
      json['updatedAt'] = DateTime.now().toIso8601String();
      await metaFile.writeAsString(jsonEncode(json));
      await _syncQueue(project);
      return task.copyWith(folderId: folderId, clearFolderId: folderId == null, updatedAt: DateTime.now());
    } catch (e) {
      throw Exception('Failed to update task folder: $e');
    }
  }

  Future<TaskModel> updateTaskDependencies(
      TaskModel task, ProjectModel project, List<String> blockedBy) async {
    try {
      final taskDir = _taskFolder(task, project);
      final metaFile = File(p.join(taskDir, AppConstants.taskMetaFile));

      if (!await metaFile.exists()) {
        throw Exception('Task meta file not found');
      }

      final content = await metaFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      json['blockedBy'] = blockedBy;
      json['updatedAt'] = DateTime.now().toIso8601String();
      await metaFile.writeAsString(jsonEncode(json));

      await _syncQueue(project);
      return task.copyWith(blockedBy: blockedBy, updatedAt: DateTime.now());
    } catch (e) {
      throw Exception('Failed to update task dependencies: $e');
    }
  }

  Future<void> deleteTask(TaskModel task, ProjectModel project) async {
    try {
      final taskDir = Directory(_taskFolder(task, project));
      if (await taskDir.exists()) {
        await taskDir.delete(recursive: true);
      }
      await _syncQueue(project);
    } catch (e) {
      throw Exception('Failed to delete task: $e');
    }
  }

  Future<String> readTaskPrompt(TaskModel task, ProjectModel project) async {
    try {
      final promptFile = File(p.join(_taskFolder(task, project), AppConstants.taskPromptFile));
      if (!await promptFile.exists()) return '';
      return await promptFile.readAsString();
    } catch (e) {
      return '';
    }
  }

  Future<void> writeTaskPrompt(
      TaskModel task, ProjectModel project, String content) async {
    try {
      final promptFile = File(p.join(_taskFolder(task, project), AppConstants.taskPromptFile));
      await promptFile.writeAsString(content);
    } catch (e) {
      throw Exception('Failed to write task prompt: $e');
    }
  }

  Future<List<ThreadMessage>> loadThread(
      TaskModel task, ProjectModel project) async {
    try {
      final threadFile =
          File(p.join(_taskFolder(task, project), AppConstants.taskThreadFile));
      if (!await threadFile.exists()) return [];

      final lines = await threadFile.readAsLines();
      final messages = <ThreadMessage>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          messages.add(ThreadMessage.fromJson(json));
        } catch (_) {}
      }
      return messages;
    } catch (e) {
      return [];
    }
  }

  Future<void> appendThreadMessage(
      TaskModel task, ProjectModel project, ThreadMessage message) async {
    try {
      final threadFile =
          File(p.join(_taskFolder(task, project), AppConstants.taskThreadFile));
      final line = '${jsonEncode(message.toJson())}\n';
      await threadFile.writeAsString(line,
          mode: FileMode.append, flush: true);
    } catch (e) {
      throw Exception('Failed to append thread message: $e');
    }
  }

  Future<List<String>> loadObservations(
      TaskModel task, ProjectModel project) async {
    try {
      final obsDir =
          Directory(p.join(_taskFolder(task, project), AppConstants.obsFolder));
      if (!await obsDir.exists()) return [];

      final contents = <String>[];
      await for (final entry in obsDir.list()) {
        if (entry is File) {
          try {
            final content = await entry.readAsString();
            contents.add('${entry.uri.pathSegments.last}\n\n$content');
          } catch (_) {}
        }
      }
      return contents;
    } catch (e) {
      return [];
    }
  }

  Future<List<SharedChatMessage>> loadSharedChat(ProjectModel project) async {
    try {
      final file = File(p.join(project.folderPath, AppConstants.sharedChatFile));
      if (!await file.exists()) return [];
      final lines = await file.readAsLines();
      final messages = <SharedChatMessage>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          messages.add(SharedChatMessage.fromJson(json));
        } catch (_) {}
      }
      return messages;
    } catch (_) {
      return [];
    }
  }

  Future<void> appendSharedChatMessage(
      ProjectModel project, SharedChatMessage message) async {
    try {
      final file = File(p.join(project.folderPath, AppConstants.sharedChatFile));
      await file.writeAsString('${jsonEncode(message.toJson())}\n',
          mode: FileMode.append, flush: true);
    } catch (e) {
      throw Exception('Failed to append shared chat message: $e');
    }
  }

  Future<bool> taskFolderExists(TaskModel task, ProjectModel project) async {
    final dir = Directory(_taskFolder(task, project));
    return dir.exists();
  }

  Future<TaskModel?> reloadTask(TaskModel task, ProjectModel project) async {
    try {
      final metaFile = File(p.join(_taskFolder(task, project), AppConstants.taskMetaFile));
      if (!await metaFile.exists()) return null;
      final json = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      return TaskModel.fromJson(json, project.id);
    } catch (_) {
      return null;
    }
  }

  // Writes queue.json at the project root with only actionable tasks
  // (pending + needs_input). The agent reads this first to know what to run.
  Future<void> _syncQueue(ProjectModel project) async {
    try {
      final tasks = await loadTasks(project);
      final folders = await _loadFolders(project);
      final folderMap = {for (final f in folders) f.id: f};
      final sharedMessages = await loadSharedChat(project);

      final completedIds = tasks
          .where((t) => t.status == TaskStatus.completed)
          .map((t) => t.id)
          .toSet();

      Map<String, dynamic> taskEntry(TaskModel t) {
        final folder = t.folderId != null ? folderMap[t.folderId] : null;
        final attrs = folder?.attributes ?? {};

        final taskMsgs = sharedMessages
            .where((m) => m.taskId == t.id)
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        final recentContext = taskMsgs.length > 10
            ? taskMsgs.sublist(taskMsgs.length - 10)
            : taskMsgs;

        return {
          'id': t.id,
          'title': t.title,
          'agent_ids': t.agentIds,
          'run_count': t.runCount,
          if (attrs.isNotEmpty) 'attributes': attrs,
          if (attrs.containsKey('working_dir'))
            'working_dir': attrs['working_dir'],
          if (recentContext.isNotEmpty)
            'recent_context': recentContext
                .map((m) => {
                      'timestamp': m.timestamp.toIso8601String(),
                      'from': m.agentName,
                      'type': m.type.jsonValue,
                      'content': m.content,
                    })
                .toList(),
        };
      }

      final pending = tasks
          .where((t) =>
              t.status == TaskStatus.pending && !t.isBlocked(completedIds))
          .map(taskEntry)
          .toList();

      final blocked = tasks
          .where((t) =>
              t.status == TaskStatus.pending && t.isBlocked(completedIds))
          .map((t) => {
                'id': t.id,
                'title': t.title,
                'blocked_by': t.blockedBy,
              })
          .toList();

      final needsInput = tasks
          .where((t) => t.needsInput)
          .map((t) => {
                'id': t.id,
                'title': t.title,
                'agent_ids': t.agentIds,
              })
          .toList();

      final queue = {
        'updated_at': DateTime.now().toIso8601String(),
        'pending': pending,
        'blocked': blocked,
        'needs_input': needsInput,
      };

      final queueFile = File(p.join(project.folderPath, AppConstants.queueFile));
      await queueFile.writeAsString(jsonEncode(queue));
    } catch (_) {
      // Queue sync failure is non-fatal
    }
  }
}
