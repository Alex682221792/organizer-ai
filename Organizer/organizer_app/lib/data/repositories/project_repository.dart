import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/project_model.dart';
import '../../core/constants/app_constants.dart';

class ProjectRepository {
  final _uuid = const Uuid();

  Future<List<ProjectModel>> loadProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final paths = prefs.getStringList(AppConstants.sharedPrefsProjectPaths) ?? [];
      final projects = <ProjectModel>[];

      for (final folderPath in paths) {
        try {
          final configFile = File(p.join(folderPath, AppConstants.projectConfigFile));
          if (await configFile.exists()) {
            final content = await configFile.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            projects.add(ProjectModel.fromJson(json, folderPath));
          }
        } catch (_) {
          // Skip malformed or missing projects
        }
      }

      return projects;
    } catch (e) {
      throw Exception('Failed to load projects: $e');
    }
  }

  Future<ProjectModel> createProject({
    required String name,
    required String description,
    required String folderPath,
    required String color,
  }) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final id = _uuid.v4();
      final now = DateTime.now();
      final project = ProjectModel(
        id: id,
        name: name,
        description: description,
        folderPath: folderPath,
        color: color,
        createdAt: now,
      );

      final configFile = File(p.join(folderPath, AppConstants.projectConfigFile));
      await configFile.writeAsString(jsonEncode(project.toJson()));

      await _writeClaudeMd(project);

      final prefs = await SharedPreferences.getInstance();
      final paths = prefs.getStringList(AppConstants.sharedPrefsProjectPaths) ?? [];
      if (!paths.contains(folderPath)) {
        paths.add(folderPath);
        await prefs.setStringList(AppConstants.sharedPrefsProjectPaths, paths);
      }

      return project;
    } catch (e) {
      throw Exception('Failed to create project: $e');
    }
  }

  Future<void> deleteProject(ProjectModel project) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final paths = prefs.getStringList(AppConstants.sharedPrefsProjectPaths) ?? [];
      paths.remove(project.folderPath);
      await prefs.setStringList(AppConstants.sharedPrefsProjectPaths, paths);
    } catch (e) {
      throw Exception('Failed to delete project: $e');
    }
  }

  Future<ProjectModel> importProject(String folderPath) async {
    try {
      final configFile = File(p.join(folderPath, AppConstants.projectConfigFile));
      if (!await configFile.exists()) {
        throw Exception('No se encontró project.json en la carpeta seleccionada');
      }
      final content = await configFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final project = ProjectModel.fromJson(json, folderPath);

      await _writeClaudeMd(project);

      final prefs = await SharedPreferences.getInstance();
      final paths = prefs.getStringList(AppConstants.sharedPrefsProjectPaths) ?? [];
      if (!paths.contains(folderPath)) {
        paths.add(folderPath);
        await prefs.setStringList(AppConstants.sharedPrefsProjectPaths, paths);
      }
      return project;
    } catch (e) {
      throw Exception('Failed to import project: $e');
    }
  }

  Future<void> updateProject(ProjectModel project) async {
    try {
      final configFile = File(p.join(project.folderPath, AppConstants.projectConfigFile));
      await configFile.writeAsString(jsonEncode(project.toJson()));
    } catch (e) {
      throw Exception('Failed to update project: $e');
    }
  }

  // Generates CLAUDE.md in the project folder so Claude Code sessions opened
  // in that directory know how to create tasks on the board without the app UI.
  // Skipped if the file already exists (allows manual customisation).
  Future<void> _writeClaudeMd(ProjectModel project) async {
    final file = File(p.join(project.folderPath, AppConstants.claudeMdFile));
    if (await file.exists()) return;
    await file.writeAsString(_claudeMdContent(project));
  }

  String _claudeMdContent(ProjectModel project) => '''
# ${project.name}

> Organizer AI project — Kanban dashboard managed by the Organizer macOS app.

**Project ID:** `${project.id}`
**Description:** ${project.description.isNotEmpty ? project.description : '(no description)'}

---

## Creating a task on the board

To add a task so it appears in the Kanban board, create the following files.
The app scans `tasks/` on startup and after every change.

### Steps

**1. Choose a UUID v4** for the task — use `uuidgen` in the terminal or any generator.

**2. Create the directory structure**

```
tasks/<uuid>/
tasks/<uuid>/obs/
```

**3. Write `tasks/<uuid>/meta.json`**

```json
{
  "id": "<uuid>",
  "title": "Short task title",
  "status": "backlog",
  "instructions": "One-line description of what the task needs",
  "createdAt": "<ISO-8601 timestamp>",
  "updatedAt": "<ISO-8601 timestamp>",
  "runCount": 0,
  "needsInput": false,
  "agentIds": [],
  "blockedBy": []
}
```

**4. Write `tasks/<uuid>/task.md`**

Full prompt/instructions for the agent. Can be identical to `instructions` or a richer, multi-section document.

---

## Task statuses

| `status` value | Board column | Meaning |
|---|---|---|
| `backlog` | Backlog | Not ready to run yet |
| `pending` | Pending | Ready — agents pick this up on the next cycle |
| `in_progress` | In Progress | Currently being executed |
| `review` | Review | Waiting for human review |
| `blocked` | Blocked | Depends on another task |
| `completed` | Completed | Done |
| `cancelled` | Cancelled | Discarded |

> **Important:** Do NOT edit `queue.json` directly — the app regenerates it automatically from `meta.json` files whenever tasks are loaded.

---

## Agent output

Agents write results to `tasks/<uuid>/obs/run-N-<timestamp>.md`.
If an agent needs human input it sets `"needsInput": true` in `meta.json` and the board shows an alert icon on the card.

---

## Shared chat

`shared_chat.jsonl` holds cross-agent messages. Each line is a JSON object:

```json
{
  "id": "<uuid>",
  "timestamp": "<ISO-8601>",
  "role": "agent | user | system",
  "agent_id": "<agent-uuid or null>",
  "agent_name": "Agent name or 'Usuario'",
  "task_id": "<task-uuid or null>",
  "task_title": "Task title (optional)",
  "type": "observation | update | decision | question | note | system",
  "content": "Message text"
}
```
''';
}
